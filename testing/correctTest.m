clc;clear all;close all;


load('../training/4. prepare patches for test/result/testPatches1.mat');

nImg = [64 64];
cin = 6;
nClass = 3;

patches_test = reshape(Ytest, nImg(1), nImg(1), cin, size(Ytest,2));

patch1=patches_test(:,:,1:3,8);
imagesc(patch1)
[p_ind, p_map] = rgb2ind(patch1, 64);


for i = 1:size(p_map)
    tmp = (p_ind == i-1);
    tmp3 = repmat(tmp,[1 1 3]);
    
    patch_tmp = patch1;
    
    patch_tmp(tmp3==0) = 0;
    
    imagesc(patch_tmp);
    
end