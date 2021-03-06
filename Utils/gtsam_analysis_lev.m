%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GTSAM Copyright 2010, Georgia Tech Research Corporation,
% Atlanta, Georgia 30332-0415
% All Rights Reserved
% Authors: Frank Dellaert, et al. (see THANKS for the full author list)
%
% See LICENSE for the license information
%
% @brief Read graph from file and perform GraphSLAM
% @author Frank Dellaert
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function outdat = gtsam_analysis_lev(runFolder, outputfolder, initialSigma, absErrorTol, relErrorTol, maxIterat)
% %% Levenberg Marquardt Optimizer Parameters

tGTSAMStart = tic;

outdat = struct();
import gtsam.*

DOPLOT = 0; % turn on and off plotting within this function
mkdir(outputfolder);

%% Find data file
datafile = strcat(runFolder,'simData.graph');

%% Initialize graph, initial estimate, and odometry noise
[graph,initial] = load2D(fullfile(datafile));

[headingAngle,sigmaHeading] = loadHeadingFromFile(datafile);

if ~isempty(headingAngle)
    
    %% Taking the Yaw Angle estimate from the data file
    vertexCount = length(headingAngle);
    
    %% Providing the prior for the poses in order to incorporate the heading information
    headingNoiseModel  = noiseModel.Diagonal.Sigmas(sigmaHeading);
    
    % Add orientation prior to all poses
    for i=2:vertexCount
        mean = initial.at(i);
        tempMean = Pose2(0,0,headingAngle(i));
        graph.add(PoseRotationPrior2D(i, tempMean, headingNoiseModel));
    end
end

%% Add a Gaussian prior on a pose in the middle
priorMean = initial.at(1);
priorNoise = noiseModel.Diagonal.Sigmas(initialSigma);
graph.add(PriorFactorPose2(1, priorMean, priorNoise)); % add directly to graph

%% Optimize using Levenberg-Marquardt optimization with an ordering from colamd
params = LevenbergMarquardtParams;
params.setAbsoluteErrorTol(absErrorTol);
params.setRelativeErrorTol(relErrorTol);
params.setMaxIterations(maxIterat);
optimizer = LevenbergMarquardtOptimizer(graph, initial, params);

tStart = tic;
result = optimizer.optimizeSafely;
tOptimization = toc(tStart);
fprintf('Optimization time for GTSAM = %f seconds \n',tOptimization)

marginals = Marginals(graph, result);
keys = KeyVector(result.keys);
estimatedPose = utilities.extractPose2(result);
estimatedFeats = utilities.extractPoint2(result);
poseCovariance = zeros(3,3,size(estimatedPose,1));
featCovariance = zeros(2,2,size(estimatedFeats,1));
globalposeXYCovariance = zeros(2,2,size(estimatedPose,1));

pcounter = 0;
fcounter = 0;

%% Extracting covariances (time consuming)
% for i = 0:keys.size-1
%     key = keys.at(i);
%     x = result.at(key);
%     if isa(x, 'gtsam.Pose2')
%         pcounter = pcounter + 1;
%         % gtsam pose covariance is in local frame
%         poseCovariance(:,:,pcounter) = marginals.marginalCovariance(key);
%         % rotate it to global frame
%         ct = cos(x.theta);
%         st = sin(x.theta);
%         gRp = [ct -st;st ct]; % rotation from pose to global
%         globalposeXYCovariance(:,:,pcounter) = gRp*poseCovariance(1:2,1:2,pcounter)*gRp'; % the global frame robot pose x-y covariance
%     end
%     if isa(x, 'gtsam.Point2')
%         fcounter = fcounter + 1;
%         featCovariance(:,:,fcounter) = marginals.marginalCovariance(key);
%     end
% end

featCovariance(:,:,1) = [];
poseCovariance(:,:,1) = [];
outdat.estimatedPose = estimatedPose';
outdat.estimatedFeats = estimatedFeats';
outdat.poseCovariance = poseCovariance;
outdat.globalposeXYCovariance = globalposeXYCovariance;
outdat.featCovariance = featCovariance;
outdat.tOptimization = tOptimization;
save(strcat(outputfolder,'gtsam_lev_results.mat'),'outdat');

%% Plot Estimates
if DOPLOT
    
    mfh = figure;
    
    plot2DTrajectory(initial, 'b-'); axis equal
    
    % Plot Covariance Ellipses
    figure(mfh);
    hold on
    plot2DTrajectory(result, 'm');%, marginals);
    plot2DPoints(result, 'm', marginals);
    figName = strcat(outputfolder,'gtsam_lev_solution.fig');
    axis tight
    axis equal
    hold off;
    saveas(mfh,figName);
    
end

tGTSAMStop = toc(tGTSAMStart);
fprintf('Total time for GTSAM = %f seconds \n',tGTSAMStop)

end

function [headingAngle, sigmaHeading] = loadHeadingFromFile(fname)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Insert data into graph by reading
% a text file.
%
% Input:
% baseDir: path to directory containig file
% fname: the name of file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('Reading sim heading data from input file...\n')

% open the file
fid = fopen(fname);

% the total number of nodes
numnodes = 0;

% heading measurements
headingAngle = [];

% heading uncertainty
sigmaHeading = 0;

% read it line by line
while true
    
    % read line
    tline = fgetl(fid);
    
    % check if it has anything in it
    if ~ischar(tline);
        break;%end of file
    end
    
    % if it had something, lets see what it had
    % Scan the line upto the first space
    % we will identify what data type this is
    str = textscan(tline,'%s %*[ ]');
    
    if strcmp(str{1},'HD2')
        
        datastr = textscan(tline,'%s %d %f %f');
        numnodes = datastr{2};
        
        % store the data in each node
        headingAngle(numnodes) =  datastr{3};
        
        if numnodes == 1
            sigmaHeading = datastr{4};
        end
            
    end
    
end

% close file
fclose(fid);

fprintf('Total nodes: %d \n', numnodes)
fprintf('Done reading heading file.\n')

end
