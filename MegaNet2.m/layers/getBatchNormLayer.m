function L = getBatchNormLayer(nData,varargin)
% constructs a batchNormLayer for data of size nData. 
%
% Adds a scaling layer when isWeight==1
%
% Return type is a NN in any case.

% default parameter
isWeight  = 0; 
useGPU    = 0;
precision = 'double';

for k=1:2:length(varargin)     % overwrites default parameter
    eval([varargin{k},'=varargin{',int2str(k+1),'};']);
end

bnL = normLayer(nData,'doNorm',[0,0,1],'useGPU',useGPU,'precision',precision);

if isWeight==1
    affL = affineScalingLayer(nData,'useGPU',useGPU,'precision',precision,'isWeight',[0,1,0]);
    L = NN({bnL,affL});
else
    L = bnL;
end