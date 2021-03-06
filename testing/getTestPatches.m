clc;clear all;close all;

if ispc

    load('..\data augmentation\1. prepareInput\result\exampler_test.mat');
else
    load('../data augmentation/1. prepareInput/result/exampler_test.mat');
end
Pat = 64;
m = ceil(Pat/2);
[Dimx, Dimy, DimzAll] = size(outtest); 
Pat = 64;
m1 = 1;
Dimz = 1;  Patz = 1;

% Number of patterns : disDim*disDim
disDimx  = ceil((Dimx  - (1+(Pat -1)*m1) + 1)/m);
disDimy  = ceil((Dimy  - (1+(Pat -1)*m1) + 1)/m);  
disDimz = ceil((Dimz - (1+(Patz-1)*m1) + 1)/m);
fprintf('\n\nNext Phase\n------------------------------------------------\n');
fprintf('Patterns retained for analysis = %d x %d x %d\n', disDimx,disDimy,disDimz);

%
X=zeros(disDimx*disDimy*disDimz,Pat^2*DimzAll);

l=1;
for i=1:disDimx
    for j=1:disDimy
        for k=1:disDimz
            %X((i-1)*disDim+j,:)=reshape(out(i:i+Pat-1,j:j+Pat-1),1,Pat^2);
            wx = 1+m*(i-1):m1:1+m*(i-1)+(Pat -1)*m1;
            wy = 1+m*(j-1):m1:1+m*(j-1)+(Pat -1)*m1;
            wz = 1:DimzAll;
           % % The "if" below is to delete completely empty patterns from calculations 
           % % you should also change to X initialization to X=[];
           % if sum(sum(out(wx,wy)))~=0
                X(l,:)=reshape(outtest(wx,wy,wz),1,Pat^2*DimzAll);
                %
                l=l+1;
           % end
        end
    end
end

Xt = X';
patches = reshape(Xt, Pat,Pat,DimzAll,[]);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% patches = sampleIMAGES_ns(outtest, 64, 300);
for i = 1:25
    subplot(5,5,i)
    imagesc(uint8(patches(:,:,1:3,i)))
    axis off
end
figure
for i = 1:25
    subplot(5,5,i)
    imagesc(uint8(patches(:,:,4:6,i)))
    axis off
end
figure
for i = 1:25
    subplot(5,5,i)
    imagesc(uint8(patches(:,:,7,i)))
    axis off
end

%%%%%%%%%%%%%%%%%%%%


testPatches_R = patches;

return
if ispc
    save('results\testPatches_regular.mat', 'testPatches_R');
else
    save('results/testPatches_regular.mat', 'testPatches_R');
end