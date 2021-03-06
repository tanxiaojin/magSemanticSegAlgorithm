classdef convFFT < convKernel 
    % classdef convFFT < convKernel
    % 2D coupled convolutions. Computed using FFTs
    %
    % Transforms feature using affine linear mapping
    %
    %     Y(theta,Y0) =  K(theta_1) * Y0 
    %
    %  where 
    % 
    %      K - convolution matrix (computed using FFTs for periodic bc)
    
    properties
        S 
    end
    
    methods
        function this = convFFT(varargin)
            this@convKernel(varargin{:});
            if nargout==0 && nargin==0
                this.runMinimalExample;
                return;
            end
            this.S = gpuVar(this.useGPU, this.precision, getEigs(this));
            
        end
        function S = getEigs(this)
            S = zeros(prod(this.nImg),prod(this.sK(1:2)));
            for k=1:prod(this.sK(1:2))
                Kk = zeros(this.sK(1:2));
                Kk(k) = 1;
                Ak = getConvMatPeriodic(Kk,[this.nImg 1]);
                
                S(:,k) = vec(fft2( reshape(full(Ak(:,1)),this.nImg(1:2)) ));
            end
        end
        function this = gpuVar(this,useGPU,precision)
            if strcmp(this.precision,'double') && (isa(gather(this.S),'single'))
                this.S = getEigs(this);
            end
            this.S = gpuVar(useGPU,precision,this.S);
        end

        function runMinimalExample(~)
            nImg   = [16 16];
            %sK     = [3 3,4,4];
            sK     = [1 1,4,4];
            
            kernel = feval(mfilename,nImg,sK);
            
            theta1 = rand(sK); 
            theta1(:,1,:) = -1; theta1(:,1,:) = 1;
            theta  = [theta1(:);];

            I  = rand(nImgIn(kernel)); I(4:12,4:12,:) = 2;
            Ik = reshape(Amv(kernel,theta,I),kernel.nImgOut());
            ITk = reshape(ATmv(kernel,theta,I),kernel.nImgOut());
            
            figure(1); clf;
            subplot(1,2,1);
            imagesc(I(:,:,1));
            title('input');
            
            subplot(1,2,2);
            imagesc(Ik(:,:,1));
            title('output');
        end
        
        function Y = Amv(this,theta,Y)
            nex   = numel(Y)/prod(nImgIn(this));
            
            % compute convolution
            AY = zeros([nImgOut(this) nex],'like',Y); %start with transpose
            theta    = reshape(theta, [prod(this.sK(1:2)),this.sK(3:4)]);
            Yh = ifft2(reshape(Y,[nImgIn(this) nex]));
            for k=1:this.sK(4)
                Sk = reshape(this.S*theta(:,:,k),nImgIn(this));
                T  = Sk .* Yh;
                AY(:,:,k,:)  = sum(T,3);
            end
            AY = real(fft2(AY));
            Y  = reshape(AY,[],nex);
        end
        
        function ATY = ATmv(this,theta,Z)
            nex =  numel(Z)/prod(nImgOut(this));
            ATY = zeros([nImgIn(this) nex],'like',Z); %start with transpose
            theta    = reshape(theta, [prod(this.sK(1:2)),this.sK(3:4)]);
            
            Yh = fft2(reshape(Z,[this.nImgOut nex]));
            for k=1:this.sK(3)
                tk = squeeze(theta(:,k,:));
                if size(this.S,2) == 1
                    tk = reshape(tk,1,[]);
                end
                Sk = reshape(this.S*tk,nImgOut(this));
                T  = Sk.*Yh;
                ATY(:,:,k,:) = sum(T,3);
            end
            ATY = real(ifft2(ATY));
            ATY = reshape(ATY,[],nex);
        end
        
        function dY = Jthetamv(this,dtheta,~,Y,~)
            nex    =  numel(Y)/nFeatIn(this);
            Y      = reshape(Y,[],nex);
            dY = getOp(this,dtheta)*Y;
        end
        
        function dtheta = JthetaTmv(this,Z,~,Y)
            %  derivative of Z*(A(theta)*Y) w.r.t. theta
            
            nex    =  numel(Y)/nFeatIn(this);
            
            dth1    = zeros([this.sK(1)*this.sK(2),this.sK(3:4)],'like',Y);
            Y     = permute(reshape(Y,[nImgIn(this) nex ]),[1 2 4 3]);
            Yh    = reshape(fft2(Y),prod(this.nImg(1:2)),nex*this.sK(3));
            Zh    = permute(ifft2(reshape(Z,[nImgOut(this) nex])),[1 2 4 3]);
            Zh     = reshape(Zh,[], this.sK(4));
            
            for k=1:prod(this.sK(1:2)) % loop over kernel components
                temp = bsxfun(@times,conj(this.S(:,k)),Yh);
                temp = reshape(temp,[],this.sK(3));
                dth1(k,:,:) = conj(temp')*Zh;
            end
            dtheta = real(reshape(dth1,this.sK));
        end
    
  
        
    end
end


