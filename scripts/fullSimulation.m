% The goal of this script is to 
% 1. Simulate the entire digital imaging pipeline
%    in the Linux-Octave setup
% 2. Play around with hyperparameters
% 
% We simulate the ISET implementation of OVT's 
% split pixel technology

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Stage 0. Setup
disp('Running Stage 0: Setup');

ieInit; % start a global vcSession which stores states. 
% runs fully locally. 

% 0.A Scene Setup
imageID = '1112201236';
wgts = [0.2306    0.012    0.01    1e-2*0.5175];  % night
% Headlight, Street light, Other, Sky light: weight ordering


% 0.B Camera Optics Setup
[oi,wvf] = oiCreate('wvf');  % create an optical image and wavefront
params = wvfApertureP;  % aperture parameters
params.nsides = 3;
params.dotmean = 50;  % dots simulate dust particles
params.dotsd = 20;
params.dotopacity =0.5;
params.dotradius = 5;
params.linemean = 50;  % lins simulate scratches
params.linesd = 20;
params.lineopacity = 0.5;
params.linewidth = 2;

aperture = wvfAperture(wvf,params);
oi = oiSet(oi,'wvf zcoeffs',0,'defocus');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Stage I. Scene Radiance to Sensor Irradiance
% Pass light through the optics
disp('Running Stage I: Optics');
scene = hsSceneCreate(imageID,'weights',wgts,'denoise',false);
opticalImage = oiCompute(oi, scene,'aperture',aperture,'crop',true,'pixel size',3e-6);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Stage II. Sensor Modelling & Capture
disp('Running Stage II: Sensor Capture');

% hyperparameters
expTime = 16e-3;
satLevel = 0.95;
pixelSize = 3e-6;  % 3 um
sensorSize = [1082 1926];  % resolution

arrayType = 'ovt';

% the split pixel tech is essentially running three sensors
% LPD-LCG, LPD-HCG, SPD 
% sensorArray is an array of these three sensors (in ORDER)
sensorArray = sensorCreateArray('array type',arrayType,...
    'pixel size same fill factor',pixelSize,...
    'exp time',expTime, ...
    'quantizationmethod','analog', ...
    'size',sensorSize);

% sensor capture
%   sensorCombined   - Data pooled from the multiple sensors in the array
%   sensorArraySplit - The individual sensors
[sensorCombined,sensorArraySplit] = sensorComputeArray(sensorArray,opticalImage,...
    'method','saturated', ...
    'saturated',satLevel);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Stage III. Image Processing
disp('Running Stage III: Image Processing');
ipLPD = ipCreate;
sensorLPDLCG = sensorArraySplit(1);
ipLPDLCG = ipCompute(ipLPD,sensorLPDLCG,'hdr white',true);
% ipWindow(ipLPDLCG,'render flag','rgb','gamma',0.5);

ipLPDHCG = ipCreate;
sensorLPDHCG = sensorArraySplit(2);
ipLPDHCG = ipCompute(ipLPDHCG,sensorLPDHCG,'hdr white',true);
% ipWindow(ipLPDHVG,'render flag','rgb','gamma',0.5);

ipSPD = ipCreate;
sensorSPD = sensorArraySplit(3);
ipSPD = ipCompute(ipSPD,sensorSPD,'hdr white',true);
% ipWindow(ipSPD,'render flag','rgb','gamma',0.5);

ipSplit = ipCreate;
ipSplit = ipCompute(ipSplit,sensorCombined,'hdr white',true);
% ipWindow(ipSplit,'render flag','rgb','gamma',0.5);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Stage IV. Save & Display
disp('Running Stage IV: Save Outputs');

rgb = ipGet(ipSplit,'srgb');
fname = fullfile(isethdrsensorRootPath,'data', imageID,'split.png');
imwrite(rgb,fname);

rgb = ipGet(ipLPDLCG,'srgb');
fname = fullfile(isethdrsensorRootPath,'data', imageID,'lpd-lcg.png');
imwrite(rgb,fname);

rgb = ipGet(ipLPDHCG,'srgb');
fname = fullfile(isethdrsensorRootPath,'data', imageID, 'lpd-hcg.png');
imwrite(rgb,fname);

rgb = ipGet(ipSPD,'srgb');
fname = fullfile(isethdrsensorRootPath,'data', imageID,'spd.png');
imwrite(rgb,fname);
