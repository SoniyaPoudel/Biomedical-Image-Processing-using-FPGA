close all;
clear;
clc;

% extracting the imageinformation
% total pixel in the image is
% 650X 367 
b = imread('sample.png');

k = 1;

% image is written from last row to the first row
% generating array where the 
% pixel information is extracted
for i = 367:-1:1
    for j = 1:650
        a(k) = b(i, j, 1);
        a(k + 1) = b(i, j, 2);
        a(k + 2) = b(i, j, 3);
        k = k + 3;
    end
end

% opening a file sample.hex
fid = fopen('sample.hex', 'wt');

% writing the information 
% in hexadecimal format
fprintf(fid, '%x\n', a);
disp('Text file write done');
disp(' ');
fclose(fid);