% StatFit1.m
% This is the initial example for statistical data fitting
% The data has been drawn from
%   2011 - U.S. Geological Survey Data Series 595
% It involves the 90 Animas river locations given in that report
% Some of the locations are duplicates (I'm not sure why)
% Where those duplicates occur, only the first listed data is used
% As a result, only 81 data locations are used here

% Load the data into memory
%   latlong - Latitude/Longitude locations
%   FOpct - Ferric Oxide percentage in sample
load StatFit1_data.mat
N = size(latlong,1);
y = FOpct;

% We rescale the data locations to [-1,1] for simplicity
% This is not required, but helps computation
latlong_shift = min(latlong);
latlong_scale = max(latlong) - min(latlong);
x = 2*(latlong - ones(N,1)*latlong_shift)./(ones(N,1)*latlong_scale) - 1;

% Choose a kernel to fit to the data
% Is DistanceMatrix returning complex numbers?
ep = 1;
rbf = @(e,r) exp(-(e*real(r)).^2);
rbf = @(e,r) exp(-(e*real(r)));

% Choose locations at which to make predictions
NN = 50;
xx = pick2Dpoints([-1 -1],[1 1],NN*ones(1,2));

% Predict results from the kriging fit
K = rbf(ep,DistanceMatrix(x,x));
K_eval = rbf(ep,DistanceMatrix(xx,x));
yp = K_eval*(K\y);

% Plot the results
% We must reshape the data for a surface plot
X1 = reshape(xx(:,1),NN,NN);
X2 = reshape(xx(:,2),NN,NN);
YP = reshape(yp,NN,NN);
h = figure;
hold on
h_dots = plot3(x(:,1),x(:,2),y,'or'); % The given data
h_stuf = surf(X1,X2,YP,'edgecolor','none');
hold off
xlabel('latitude')
ylabel('longitude')
zlabel('Ferric Oxide percentage')
