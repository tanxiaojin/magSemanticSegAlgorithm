classdef DoubleHamiltonianNN < abstractMegaNetElement
    % Double Layer Hamiltonian block
    %
    % Z_k+1 = Z_k - h*layer1(Y_k, theta_1),  
    % Y_k+1 = Y_k + h*layer2(Z_k+1,theta_2) 
    %
    % The input features are divided into Y and Z here based on the sizes 
    % of the layers. The layers do not have to have the same size.
    properties
        layer1
        layer2
        nt
        h
        outTimes
        Q
        useGPU
        precision
    end
    
    methods
        function this = DoubleHamiltonianNN(layer1,layer2,nt,h,varargin)
            if nargin==0
                this.runMinimalExample;
                return;
            end
            useGPU    = [];
            precision = [];
            outTimes  = zeros(nt,1); outTimes(end)=1;
            Q = 1.0;
            for k=1:2:length(varargin)     % overwrites default parameter
                eval([varargin{k},'=varargin{',int2str(k+1),'};']);
            end
            if not(isempty(useGPU))
                layer1.useGPU = useGPU;
                layer2.useGPU = useGPU;
            end
            if not(isempty(precision))
                layer1.precision = precision;
                layer2.precision = precision;
            end
            if nFeatOut(layer1)~=nFeatIn(layer2) && nFeatIn(layer1)~=nFeatOut(layer2)
                error('number of input and output features must agree');
            end
            this.layer1 = layer1;
            this.layer2   = layer2;
            this.nt       = nt;
            this.h        = h;
            this.outTimes = outTimes;
            this.Q        = Q;
        end
        
        function n = nTheta(this)
            n = this.nt*(nTheta(this.layer1)+ nTheta(this.layer2));
        end
        function n = nFeatIn(this)
            n = nFeatIn(this.layer1)+nFeatIn(this.layer2);
        end
        function n = nFeatOut(this)
            n = nFeatIn(this);
        end

        function n = nDataOut(this)
           if numel(this.Q)==1
               n = nnz(this.outTimes)*nFeatOut(this);
           else
               n = nnz(this.outTimes)*size(this.Q,1);
           end
        end
        
        function theta = initTheta(this)
            theta = repmat([vec(initTheta(this.layer1));...
                            vec(initTheta(this.layer2))],this.nt,1);
        end
        
        function [th1,th2] = split(this,x)
           x   = reshape(x,[],this.nt);
           th1 = x(1:nTheta(this.layer1),:);
           th2 = x(nTheta(this.layer1)+1:end,:);
        end
        function [Y,Z] = splitData(this,X)
           nex = numel(X)/nFeatIn(this);
           X   = reshape(X,[],nex);
           Y   = X(1:nFeatIn(this.layer1),:);
           Z   = X(nFeatIn(this.layer1)+1:end,:);
        end
        % ------- apply forward problems -----------
        function [Xdata,X,tmp] = apply(this,theta,X0)
            
            [Y,Z] = splitData(this,X0);
            if nargout>1;    tmp = cell(this.nt+1,4); tmp{1,1} = Y; end
            [th1,th2] = split(this,theta);
            Xdata = zeros(0,size(Y,2),'like',Y);
            for i=1:this.nt
                
                [dZ,~,tmp{i,3}] = apply(this.layer1,th1(:,i),Y);
                Z = Z - this.h*dZ;
                if nargout>1;   tmp{i,2} = Z; end
                
                [dY,~,tmp{i,4}] = apply(this.layer2,th2(:,i),Z);
                Y = Y + this.h*dY;
                
                if nargout>1, tmp{i+1,1} = Y; tmp{i+1,2} = Z; end
                if this.outTimes(i)==1
                    Xdata = [Xdata; this.Q*[Y;Z]];
                end
            end
            X = [Y;Z];
        end
        
        % -------- Jacobian matvecs ---------------
        function [dXdata,dX] = JYmv(this,dX,theta,Y,tmp)
            nex = numel(Y)/nFeatIn(this);
            if isempty(dX) || (numel(dX)==0 && dX==0.0)
                dX     = zeros(nFeatOut(this),nex,'like',Y);
                dXdata = zeros(nDataOut(this),nex,'like',Y);
                return
            end
            
            [dY,dZ]   = splitData(this,dX);
            [th1,th2] = split(this,theta);
            dXdata = zeros(0,nex,'like',Y);
            for i=1:this.nt
                
                dZ = dZ - this.h*JYmv(this.layer1,dY,th1(:,i),tmp{i,1},tmp{i,3});
                
                dY = dY + this.h*JYmv(this.layer2,dZ,th2(:,i),tmp{i,2},tmp{i,4});
                
                if this.outTimes(i)==1
                    dXdata = [dXdata; this.Q*[dY;dZ]];
                end
            end
        end
        
%         function [dXdata,dX] = Jthetamv(this,dtheta,theta,~,tmp)
%             dY = 0.0;
%             dZ = 0.0;
%             [th1,th2]   = split(this,theta);
%             [dth1,dth2] = split(this,dtheta);
%             dXdata = [];
%             for i=1:this.nt
%                 dZ = dZ - this.h*Jthetamv(this.layer1,dth1(:,i),th1(:,i),tmp{i,1},tmp{i,3});
%                 dY = dY + this.h*Jthetamv(this.layer2,dth2(:,i),th2(:,i),tmp{i,2},tmp{i,4});
%                 if this.outTimes(i)==1
%                     dXdata = [dXdata; this.Q*[dY;dZ]];
%                 end
%             end
%             dX = [dY;dZ];
%         end
%         
        
        function [dXdata,dX] = Jmv(this,dtheta,dX,theta,~,tmp)
            if isempty(dX)
                dY = 0.0;
                dZ = 0.0;
            elseif numel(dX)>1
                [dY,dZ] = splitData(this,dX);
            end
            [th1,th2]   = split(this,theta);
            [dth1,dth2] = split(this,dtheta);
            dXdata = [];
            for i=1:this.nt
                 dZ = dZ - this.h*Jmv(this.layer1,dth1(:,i),dY,th1(:,i),tmp{i,1},tmp{i,3});
                 dY = dY + this.h*Jmv(this.layer2,dth2(:,i),dZ,th2(:,i),tmp{i,2},tmp{i,4});
                if this.outTimes(i)==1
                    dXdata = [dXdata; this.Q*[dY;dZ]];
                end
            end
            dX = [dY;dZ];
        end
        
        % -------- Jacobian' matvecs ----------------
        function W = JYTmv(this,Wdata,W,theta,Y,tmp)
            nex = numel(Y)/nFeatOut(this);
            if ~isempty(Wdata)
               Wdata  = reshape(Wdata,[],nnz(this.outTimes),nex);
               WdataY = Wdata(1:nFeatIn(this.layer1),:,:);
               WdataZ = Wdata(nFeatIn(this.layer1)+1:end,:,:);
            end
            if isempty(W)
                WY = 0;
                WZ = 0;
            elseif not(isscalar(W))
                [WY,WZ] = splitData(this,W);
            end
            [th1,th2]  = split(this,theta);
            cnt = nnz(this.outTimes);
            for i=this.nt:-1:1
                if this.outTimes(i)==1
                    WY = WY + this.Q'*squeeze(WdataY(:,cnt,:));
                    WZ = WZ + this.Q'*squeeze(WdataZ(:,cnt,:));
                    cnt=cnt-1;
                end
                dWZ = JYTmv(this.layer2,WY,[],th2(:,i),tmp{i,2},tmp{i,4});
                WZ  = WZ + this.h*dWZ;
                
                dWY = JYTmv(this.layer1,WZ,[],th1(:,i),tmp{i,1},tmp{i,3});
                WY  = WY - this.h*dWY;
            end
            W = [WY;WZ];
        end
        
        function [dtheta,W] = JTmv(this,Wdata,W,theta,Y,tmp,doDerivative)
            if not(exist('doDerivative','var')) || isempty(doDerivative)
               doDerivative =[1;0]; 
            end
            
            nex = numel(Y)/nFeatOut(this);
            if ~isempty(Wdata)
               Wdata  = reshape(Wdata,[],nnz(this.outTimes),nex);
               WdataY = Wdata(1:nFeatIn(this.layer1),:,:);
               WdataZ = Wdata(nFeatIn(this.layer1)+1:end,:,:);
            end
            if isempty(W)
                WY = 0;
                WZ = 0;
            elseif not(isscalar(W))
                [WY,WZ] = splitData(this,W);
            end
            [th1,th2]   = split(this,theta);
            [dth1,dth2] = split(this,0*theta);
            
            cnt = nnz(this.outTimes);
            for i=this.nt:-1:1
                if this.outTimes(i)==1
                    WY = WY + this.Q'*squeeze(WdataY(:,cnt,:));
                    WZ = WZ + this.Q'*squeeze(WdataZ(:,cnt,:));
                    cnt=cnt-1;
                end
                [dt2,dWZ] = JTmv(this.layer2,WY,[],th2(:,i),tmp{i,2},tmp{i,4});
                WZ  = WZ + this.h*dWZ;
                dth2(:,i) = this.h*dt2;
                
                [dt1,dWY] = JTmv(this.layer1,WZ,[],th1(:,i),tmp{i,1},tmp{i,3});
                WY  = WY - this.h*dWY;
                dth1(:,i) = -this.h*dt1;
            end
            dtheta = vec([dth1;dth2]);
            W = [WY;WZ];
            if nargout==1 && all(doDerivative==1)
                dtheta=[dtheta; W(:)];
            end

        end
        % ------- functions for handling GPU computing and precision ----
        function this = set.useGPU(this,value)
            if (value~=0) && (value~=1)
                error('useGPU must be 0 or 1.')
            else
                this.layer1.useGPU  = value;
                this.layer2.useGPU  = value;
            end
        end
        function this = set.precision(this,value)
            if not(strcmp(value,'single') || strcmp(value,'double'))
                error('precision must be single or double.')
            else
                this.layer1.precision = value;
                this.layer2.precision = value;
            end
        end
        function useGPU = get.useGPU(this)
            useGPU = this.layer1.useGPU;
        end
        function precision = get.precision(this)
            precision = this.layer1.precision;
        end
        
        function runMinimalExample(~)
            
            layer = doubleSymLayer(dense([2,2]));
%             layer = singleLayer(affineTrafo(dense([2,2])));
            net   = DoubleHamiltonianNN(layer,layer,100,.1);
            Y = [1;1;1;1];
            theta =  [vec([2 1;-1 2]);vec([2 -1;1 2])];
            theta = vec(repmat(theta,1,net.nt));

            
            [Yd,YN, tmp] = apply(net,theta,Y);
            Ys = reshape(cell2mat(tmp(:,1)),2,[]);
            
            
            figure(1); clf;
            plot(Y(1,:),Y(2,:),'.r','MarkerSize',20);
            hold on;
            plot(Ys(1,:),Ys(2,:),'-k');
            plot(YN(1,:),YN(2,:),'.b','MarkerSize',20);
            
            
            return
            D   = affineTrafo(dense(nK));
            S   = singleLayer(D);
            net = LeapFrogNN(S,2,.01);
            mb  = randn(nTheta(net),1);
            
            Y0  = randn(nK(2),nex);
            [Y,tmp]   = net.apply(mb,Y0);
            dmb = reshape(randn(size(mb)),[],net.nt);
            dY0  = randn(size(Y0));
            
            dY = net.Jmv(dmb(:),dY0,mb,[],tmp);
            for k=1:14
                hh = 2^(-k);
                
                Yt = net.apply(mb+hh*dmb(:),Y0+hh*dY0);
                
                E0 = norm(Yt(:)-Y(:));
                E1 = norm(Yt(:)-Y(:)-hh*dY(:));
                
                fprintf('h=%1.2e\tE0=%1.2e\tE1=%1.2e\n',hh,E0,E1);
            end
            
            W = randn(size(Y));
            t1  = W(:)'*dY(:);
            
            [dWdmb,dWY] = net.JTmv(W,mb,[],tmp);
            t2 = dmb(:)'*dWdmb(:) + dY0(:)'*dWY(:);
            
            fprintf('adjoint test: t1=%1.2e\tt2=%1.2e\terr=%1.2e\n',t1,t2,abs(t1-t2));
            
            
            
            
            
        end
    end
    
end

