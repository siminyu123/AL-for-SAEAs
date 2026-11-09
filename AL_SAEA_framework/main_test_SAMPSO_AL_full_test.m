%% Full test for SAMPSO_AL in different groups for figures
% AL selection strategies for the first stage of SA-MPSO:
% A: DIST B:ERR AB:ERRDIST ABor:ERR/DIST 
% BCOVor:ERR/COV BCOV:ERRCOV 
% ABadapt:ERR/DISTadapt
% BCOVadapt:ERR/COVadapt

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

% Fixed folder for resuming
cfg.testDir = fullfile(cfg.resultRoot, 'SAMPSO_full_test');
cfg.resumeFromTestDir = true;

% quick test
cfg.algorithms = {'SA_MPSO_AL_A'};
cfg.runs = 1;
cfg.problems = {'ACKLEY'};
cfg.dims = [50];

%% just for plotting in groups 
% all compare
% cfg.algorithms = { ...
%     'SA_MPSO_recreated', ...
%     'SA_MPSO_AL_COV', ...
%     'SA_MPSO_AL_ABOR', ...
%     'SA_MPSO_AL_BCOVadapt',...
%     'SA_MPSO_AL_ABadapt',...
%     'SA_MPSO_AL_A', ...
%     'SA_MPSO_AL_B', ...
%     'SA_MPSO_AL_COM1',...
%     'SA_MPSO_AL_AB', ...
%     'SA_MPSO_AL_BCOV',...
%     'SA_MPSO_AL_BCOVor'};
% cfg.runs = 10;

% group A: single 
% cfg.algorithms = { ...
%     'SA_MPSO_recreated', ...
%     'SA_MPSO_AL_A', ...
%     'SA_MPSO_AL_B', ...
%     'SA_MPSO_AL_COV', ...
%     'SA_MPSO_AL_COM1'}; 
% cfg.runs = 10;

% % group B： combine
% ERR DIST family
% cfg.algorithms = { ...
%     'SA_MPSO_recreated', ...
%     'SA_MPSO_AL_A', ...
%     'SA_MPSO_AL_B', ...
%     'SA_MPSO_AL_AB', ...
%     'SA_MPSO_AL_ABOR'};
% cfg.runs = 10;
% 
% ERR COV family
% cfg.algorithms = { ...
%     'SA_MPSO_recreated', ...
%     'SA_MPSO_AL_AB', ...
%     'SA_MPSO_AL_ABOR', ...
%     'SA_MPSO_AL_BCOV',...
%     'SA_MPSO_AL_BCOVor'};
% cfg.runs = 10;

% % group C: adaptive compare, BCOV AB seems to be better than B/COV A/B
% cfg.algorithms = { ...
%     'SA_MPSO_recreated', ...
%     'SA_MPSO_AL_BCOVADAPT',...
%     'SA_MPSO_AL_ABADAPT',...
%     'SA_MPSO_AL_BCOV',...
%     'SA_MPSO_AL_AB',...
%     'SA_MPSO_AL_ABOR', ...
%     'SA_MPSO_AL_BCOVor'};
% cfg.runs = 10;

% cfg.problems = {'ACKLEY','ROSENBROCK','GRIEWANK','CEC05_f10','CEC05_f19'};
% cfg.dims = [50, 100];

%% other parameters 
cfg.maxFEs = 1000;
cfg.seedBase = 20260602;

% Keep reuseExisting false to avoid pulling old results from other folders.
cfg.reuseExisting = false;
cfg.continueOnError = true;

cfg.samps_al = struct();
cfg.samps_al.pickRatio = 0.5;
cfg.samps_al.verbose = false;
cfg.samps_al.stageVerbose = false;
cfg.samps_al.stageLogEvery = 1;

cfg.samps_al.adaptPatience = 4;
cfg.samps_al.adaptBlockLength = 1;
cfg.samps_al.adaptImproveTol = 1e-3;
cfg.samps_al.releaseEnabled = false;

cfg.plot = struct();
cfg.plot.enabled = true;
cfg.plot.statistic = 'mean';
cfg.plot.saveFig = false;
cfg.plot.savePng = true;
cfg.plot.savePdf = true;
cfg.plot.visible = 'off';

[results, summaryTable, failureTable, testDir] = start_experiment(cfg); 
print_result_rankings(summaryTable, testDir);
fprintf('\nFinished. Results are in:\n%s\n', testDir);