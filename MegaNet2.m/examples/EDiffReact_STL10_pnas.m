% =========================================================================
%
% STL10 Reaction Diffusion CNN Example
%
% =========================================================================

clear all; clc;
%%
addpath('../stl10_matlab/')
[Y0,C,Ytest,Ctest] = setupSTL(500,800);
%%
nImg = [96 96];
cin = 3;

%%
% choose file for results and specify whether or not to retrain
resFile = sprintf('%s.mat',mfilename);
doTrain = true;

% set GPU flag and precision
useGPU = 0;
precision='single';

[Y0,C,Ytest,Ctest] = gpuVar(useGPU,precision,Y0',C,Ytest,Ctest);

%% choose convolution
if useGPU
    cudnnSession = convCuDNN2DSession();
    conv = @(varargin)convCuDNN2D(cudnnSession,varargin{:});
else
    conv = @convMCN;
end

%% setup network
doNorm = 1;
% nLayer = @getTVNormLayer
nLayer = @getBatchNormLayer;

miniBatchSize = 50;
act1 = @reluActivation;
actc = @reluActivation;
act  = @reluActivation;

nf  = 2*[16;32;64;64];
nt  = 4*[1;1;1];
h  = 1*[1;1;1];

blocks    = cell(0,1); RegOps = cell(0,1);

%% Block to open the network
nL = nLayer([prod(nImg(1:2)) nf(1) miniBatchSize],'isWeight',1);
blocks{end+1} = NN({singleLayer(conv(nImg,[3 3 cin nf(1)]),'activation', act1,'nLayer',nL)},'useGPU',useGPU,'precision',precision);
RegOps{end+1} = opEye(nTheta(blocks{end}));
%% UNIT
for k=1:numel(h)
    nImgc = nImg/(2^(k-1));
    % IMEX layer
    % Start with implicit laye
    sKi      = [3,3,nf(k)];
    layerIMP = linearNegLayer(convBlkDiagFFT(nImgc,sKi,'useGPU',useGPU,'precision',precision));
    %layerIMP = linearNegLayer(convCircFFT(nImg,sKi));

    % explicit layer
    sKe = [1,1,nf(k),nf(k)];
    nL  = nLayer([prod(nImgc(1:2)) nf(k) miniBatchSize],'isWeight',1);
    layerEXP = singleLayer(conv(nImgc,sKe,'useGPU',useGPU,'precision',precision),'nLayer',nL);

    % Put it together
    blocks{end+1} = iResNN(layerEXP,layerIMP,nt(k),h(k));

    % regularization
    RegOps{end+1} = opEye(nTheta(blocks{end}));
    
    % Connector block    
    nL = nLayer([prod(nImgc(1:2)) nf(k+1) miniBatchSize], 'isWeight',1);
    Kc = conv(nImgc,[1,1,nf(k),nf(k+1)]);
    blocks{end+1} = NN({singleLayer(Kc,'activation',actc,'nLayer',nL)},'useGPU',useGPU,'precision',precision);
    regD = gpuVar(useGPU,precision,[ones(nTheta(Kc),1); zeros(nTheta(nL),1)]);
    RegOps{end+1} = opDiag(regD);
    
    if k<numel(h)
        blocks{end+1} = connector(opPoolMCN([nImgc nf(k+1)],2));
        RegOps{end+1} = opEye(nTheta(blocks{end}));
    end
end

%% Connector block
B = gpuVar(useGPU,precision,kron(eye(nf(k+1)),ones(prod(nImgc),1)));
blocks{end+1} = connector(B'/prod(nImgc));
RegOps{end+1} = opEye(nTheta(blocks{end}));

%% Put it all together
net   = MegaNet(blocks);
pLoss = softmaxLoss();

theta  = initTheta(net);
W      = 0.1*vec(randn(10,nFeatOut(net)+1));
W = min(W,.2);
W = max(W,-.2);

% RegOpW = blkdiag(opGrad(nImgc/2,nf(end)*10,ones(2,1)),opEye(10));
RegOpW = blkdiag(opEye(numel(W)));
RegOpW.precision = precision;
RegOpW.useGPU = useGPU;

RegOpTh = blkdiag(RegOps{:});
RegOpTh.precision = precision;
RegOpTh.useGPU = useGPU;

pRegW  = tikhonovReg(RegOpW,4e-4,[],'useGPU',useGPU,'precision',precision);
pRegKb = tikhonovReg(RegOpTh,4e-4,[],'useGPU',useGPU,'precision',precision);

%% Prepare optimization
fctn = dnnBatchObjFctn(net,pRegKb,pLoss,pRegW,Y0,C,'batchSize',miniBatchSize,'useGPU',useGPU,'precision',precision);
fval = dnnBatchObjFctn(net,[],pLoss,[],Ytest,Ctest,'batchSize',miniBatchSize,'useGPU',useGPU,'precision',precision);
% fval = [];
%%
opt = sgd();
opt.nesterov     = false;
opt.ADAM         = false;
opt.miniBatch    = miniBatchSize;
opt.out          = 1;

%% do learning
lr     =[0.1*ones(50,1); 0.01*ones(20,1); 0.001*ones(20,1); 0.0001*ones(10,1)];
opt.learningRate     = @(epoch) lr(epoch);
opt.maxEpochs    = numel(lr);
x0 = [theta(:);W(:)];
 keyboard
 
[xOpt,His] = solve(opt,fctn,x0,fval);
    
keyboard;


for i=1:numel(alphaW)
    fctn.pRegW.alpha = alphaW(i);
    
    fctn.pRegTheta.alpha = alphaT(i);
    [xOpt,His] = solve(opt,fctn,xOpt,fval);
    opt.learningRate = 1e-3;
    [xOpt,His] = solve(opt,fctn,xOpt,fval);
    opt.learningRate = 1e-4;
    [xOpt,His] = solve(opt,fctn,xOpt,fval);

    [thOpt,WOpt] = split(fctn,gather(xOpt));
    save(sprintf('EResNN_STL10_avg_instNorm_%d_%d_%d-%d-%d_aW_%1.1e_aT_%1.1e.mat',numel(h),doNorm,nt,nf,fctn.pRegW.alpha,fctn.pRegTheta.alpha),'thOpt','WOpt','His')
    opt.maxEpochs = 50;
    opt.learningRate = @(epoch) 1e-5/sqrt(epoch);
    if max(His.his(:,end)) > best(3);
        best =  [fctn.pRegW.alpha fctn.pRegTheta.alpha max(His.his(:,end))]
    end
end