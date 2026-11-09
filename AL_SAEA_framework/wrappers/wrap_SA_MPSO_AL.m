function result = wrap_SA_MPSO_AL(problemName, D, runIndex, cfg, algName)
% Strategies:
%   'A' : low predicted objective + archive distance.
%   'B' : low predicted objective + local-error-based uncertainty.
%   'AB'   : quota split between DIST and ERR.
%   'ABOR' : alternate full half-budget selection between DIST and ERR.
%   'COM1' : weighted committee. First keep only top-predicted
%            candidates, then select by weighted mean prediction + disagreement.
%   'COV'  : distance is measured to both archive and already selected batch points.
%   'BCOV'   : quota split between ERR and COV.
%   'BCOVOR' : alternate whole selected batch between COV and ERR.
%   'COVCOM1'    : quota split between COM1 and COV.
%   'COVCOM1OR'  : alternate whole selected batch between COV and COM1.
%   'BCOVADAPT'   : adaptive B/COV switching after Status-1 stagnation.
%   'ABADAPT'     : adaptive B/A switching after Status-1 stagnation.
%   'COVCOM1ADAPT': adaptive COM1/COV switching after Status-1 stagnation.

if nargin < 5 || isempty(algName)
    algName = 'SA_MPSO_AL_A';
end

oldPath = path;
oldDir = pwd;
cleanup = onCleanup(@() cleanup_path(oldPath, oldDir));

algoDir = fullfile(cfg.codeRoot, 'SA-MPSO_recreated');
benchmarkRoot = fullfile(cfg.frameworkRoot, 'benchmarks');
assert(exist(algoDir, 'dir') == 7, 'Cannot find SA-MPSO_recreated folder: %s', algoDir);

addpath(genpath(algoDir));
addpath(fullfile(cfg.frameworkRoot, 'algorithms_al'));
cd(algoDir);
problem = get_problem(problemName, D, benchmarkRoot);

% The recreated SA-MPSO implementation accepts scalar bounds only.
if any(abs(problem.LB - problem.LB(1)) > 0) || any(abs(problem.UB - problem.UB(1)) > 0)
    error('SA-MPSO AL variants support scalar bounds only.');
end

alOptions = struct();
if isfield(cfg, 'samps_al')
    alOptions = cfg.samps_al;
end
if ~isfield(alOptions, 'pickRatio')
    alOptions.pickRatio = 0.5;
end
if ~isfield(alOptions, 'verbose')
    alOptions.verbose = false;
end

algKey = upper(char(algName));
resultAlgName = char(algName);

switch algKey
    case 'SA_MPSO_AL_A'
        strategy = 'A';
    case 'SA_MPSO_AL_B'
        strategy = 'B';
    case 'SA_MPSO_AL_AB'
        strategy = 'AB';
    case 'SA_MPSO_AL_ABOR'
        strategy = 'ABOR';
    case 'SA_MPSO_AL_COM1'
        strategy = 'COM1';
    case 'SA_MPSO_AL_COV'
        strategy = 'COV';
    case 'SA_MPSO_AL_BCOV'
        strategy = 'BCOV';
    case 'SA_MPSO_AL_BCOVOR'
        strategy = 'BCOVOR';
    case 'SA_MPSO_AL_COVCOM1'
        strategy = 'COVCOM1';
    case 'SA_MPSO_AL_COVCOM1OR'
        strategy = 'COVCOM1OR';
    case 'SA_MPSO_AL_BCOVADAPT'
        strategy = 'BCOVADAPT';
    case 'SA_MPSO_AL_ABADAPT'
        strategy = 'ABADAPT';
    case 'SA_MPSO_AL_COVCOM1ADAPT'
        strategy = 'COVCOM1ADAPT';
    otherwise
        error('Unknown SA-MPSO AL variant: %s', algName);
end

alOptions.strategy = strategy;

tic;
[bestF, bestX, curve, rawCore] = SA_MPSO_AL_plus( ...
    problem.fun, D, problem.LB(1), problem.UB(1), cfg.maxFEs, alOptions);
elapsed = toc;

raw = rawCore;
raw.wrapperStrategy = strategy;
result = make_result(char(resultAlgName), problemName, D, runIndex, bestF, bestX, curve, elapsed, raw, cfg);
end

function cleanup_path(oldPath, oldDir)
path(oldPath);
cd(oldDir);
end