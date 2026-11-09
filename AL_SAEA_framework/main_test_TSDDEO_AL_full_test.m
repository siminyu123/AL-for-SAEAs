%% Full test for TSDDEO_AL, always stores the results in the same folder. 
% AL selection strategies for the first stage of TS-DDEO:
%   TSDDEO_AL_DIST     distance-based AL
%   TSDDEO_AL_COM      committee-disagreement AL
%   TSDDEO_AL_DISTCOM  alternating DIST and COM

clear; clc;

thisFile = mfilename('fullpath');
frameworkRoot = fileparts(thisFile);
projectRoot = fileparts(frameworkRoot);

restoredefaultpath;
addpath(genpath(frameworkRoot));

cfg = struct();
cfg.frameworkRoot = frameworkRoot;
cfg.codeRoot = projectRoot;
cfg.resultRoot = fullfile(frameworkRoot, 'results');

cfg.testDir = fullfile(cfg.resultRoot, 'TSDDEO_full_test');
cfg.resumeFromTestDir = true;

% quick test
cfg.algorithms = {'TSDDEO_AL_DIST'};
cfg.problems = {'ACKLEY'};
cfg.dims = [50];
cfg.runs = 1;

% full test
% cfg.algorithms = { ...
%     'TSDDEO', ...
%     'TSDDEO_AL_DIST', ...
%     'TSDDEO_AL_COM', ...
%     'TSDDEO_AL_DISTCOM'};
% 
% cfg.problems = {'ELLIPSOID', 'ACKLEY', 'GRIEWANK', 'ROSENBROCK', ...
%                 'CEC05_f19'};
% 
% cfg.dims = [50 100];
% cfg.runs = 10;

%% other parameters
cfg.maxFEs = 1000;
cfg.seedBase = 20260602;

% Keep false for resuming from the fixed folder
cfg.reuseExisting = false;

% Shared TS-DDEO AL settings. Prediction dominant.
cfg.tsddeo_al.stage1Pick = 1;
cfg.tsddeo_al.predWeight = 0.7;
cfg.tsddeo_al.distWeight = 0.3;
cfg.tsddeo_al.comPredWeight = 0.7;
cfg.tsddeo_al.comUncWeight = 0.3;
cfg.tsddeo_al.comSpreadFactors = [0.5 1.0 2.0];

cfg.plot.visible = 'off';
cfg.plot.savePng = true;
cfg.plot.saveFig = false;
cfg.plot.savePdf = true;
cfg.plot.statistic = 'mean';

[results, summaryTable, failureTable, testDir] = start_experiment(cfg); 
print_result_rankings(summaryTable, testDir);
fprintf('\nFinished. Results are in:\n%s\n', testDir);

disp(summaryTable);
if ~isempty(failureTable)
    disp('Some cases failed. Check failures.csv.');
    disp(failureTable);
end
