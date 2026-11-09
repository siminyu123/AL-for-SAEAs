function result = wrap_TSDDEO_AL(problemName, D, runIndex, cfg, algName)
% AL selection strategies for the first stage of TS-DDEO:
%   TSDDEO_AL_DIST     distance-based AL
%   TSDDEO_AL_COM      committee-disagreement AL
%   TSDDEO_AL_DISTCOM  alternating DIST and COM


if nargin < 5 || isempty(algName)
    algName = 'TSDDEO_AL_DISTCOM';
end
algName = char(algName);
algKey = upper(strrep(algName, '-', '_'));

oldPath = path;
oldDir = pwd;
cleanup = onCleanup(@() cleanup_path(oldPath, oldDir));

oldWarnState = warning;
cleanupWarn = onCleanup(@() warning(oldWarnState)); 
warning('off', 'MATLAB:singularMatrix');
warning('off', 'MATLAB:nearlySingularMatrix');
warning('off', 'MATLAB:rankDeficientMatrix');
warning('off', 'MATLAB:dispatcher:nameConflict');

algoDir = fullfile(cfg.codeRoot, 'TS-DDEO');
algoAlDir = fullfile(cfg.frameworkRoot, 'algorithms_al');
benchmarkRoot = fullfile(cfg.frameworkRoot, 'benchmarks');
assert(exist(algoDir, 'dir') == 7, 'Cannot find TS-DDEO folder: %s', algoDir);
assert(exist(algoAlDir, 'dir') == 7, 'Cannot find algorithms_al folder: %s', algoAlDir);

addpath(genpath(algoDir), '-end');
addpath(algoAlDir, '-begin');
cd(algoDir);

problem = get_problem(problemName, D, benchmarkRoot);

if isfield(cfg, 'tsddeo_al')
    alOptions = cfg.tsddeo_al;
else
    alOptions = struct();
end

switch algKey
    case 'TSDDEO_AL_DIST'
        alOptions.strategy = 'DIST';

    case 'TSDDEO_AL_COM'
        alOptions.strategy = 'COM';

    case 'TSDDEO_AL_DISTCOM'
        alOptions.strategy = 'DISTCOM';
    otherwise
        error('Unknown TSDDEO_plus variant: %s', algName);
end

resultAlgName = algKey;
alOptions.MaxFEs = cfg.maxFEs;

tic;
[hx, hf, NFEs, MaxFEs, CE, gfs, alLog] = TSDDEO_plus( ...
    problem.fun, D, problem.LB, problem.UB, alOptions);
elapsed = toc;

curve = gfs(1:min(NFEs, numel(gfs)));
if isempty(curve)
    curve = best_curve_from_values(CE(1:NFEs,2));
end
[bestF, idx] = min(hf);
bestX = hx(idx,:);

raw = struct();
raw.hx = hx;
raw.hf = hf;
raw.NFEs = NFEs;
raw.MaxFEs = MaxFEs;
raw.CE = CE;
raw.gfs = gfs;
raw.alLog = alLog;
raw.alOptions = alOptions;

result = make_result(resultAlgName, problemName, D, runIndex, ...
    bestF, bestX, curve, elapsed, raw, cfg);
end

function cleanup_path(oldPath, oldDir)
path(oldPath);
cd(oldDir);
end
