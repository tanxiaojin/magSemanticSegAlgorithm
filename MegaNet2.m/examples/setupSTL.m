function[Ytrain,Ctrain,Yval,Cval ] = setupSTL(nTrain,nVal)

% baseDir = fileparts(which('startupMegaNet.m'));
% stlDir = fullfile(baseDir,'..','stl10_matlab');
% addpath(stlDir);

load train.mat
Ytrain = double(X);
ptrain = randi(size(Ytrain,1),nTrain,1);
Ytrain = Ytrain(ptrain,:);
nex = size(Ytrain,1);
Ytrain = reshape(normalizeData(reshape(Ytrain',96*96,[])')',[],nex);
Ctrain = zeros(nex,10);
ind    = sub2ind(size(Ctrain),(1:size(Ctrain,1))',y(ptrain));
Ctrain(ind) = 1;

load  test.mat
Yval = double(X);
pval = randi(size(Yval,1),nVal,1);
Yval = Yval(pval,:);
nv = size(Yval,1);
Yval = reshape(normalizeData(reshape(Yval',96*96,[])')',[],nv);
Cval = zeros(nv,10);
ind    = sub2ind(size(Cval),(1:size(Cval,1))',y(pval));
Cval(ind) = 1;

Ytrain = Ytrain';
Ctrain = Ctrain';
Cval   = Cval';