function result = wrap_TSDDEO(problemName, D, runIndex, cfg)
% Run original TS-DDEO on one problem.

% TS-DDEO needs 
% - Statistics and Machine Learning Toolbox, 
% - Deep Learning Toolbox. 

% automatically return to current path and folder when the wrapper finishes
oldPath = path;
oldDir = pwd;
cleanup = onCleanup(@() cleanup_path(oldPath, oldDir));

algoDir = fullfile(cfg.codeRoot, 'TS-DDEO');
benchmarkRoot = fullfile(cfg.frameworkRoot, 'benchmarks');
assert(exist(algoDir, 'dir') == 7, 'Cannot find TS-DDEO folder: %s', algoDir);

% add TS-DDEO and subfolders to matlab path
addpath(genpath(algoDir));
cd(algoDir); % run from TS-DDEO folder
problem = get_problem(problemName, D, benchmarkRoot);

% hx: history X, each row is one exactly evaluated solution
% hf: history fitness corresponding to hx
% NFEs: number of exact evaluations used
% MaxFEs: maximum number of exact evaluations
% CE: archive for the exact fitness, size (MaxFEs,2), 
%     (,1) for index and (,2) for exact objective value
% gfs: best-so-far convergence curve, for plotting
tic;
[hx, hf, NFEs, MaxFEs, CE, gfs] = TSDDEO(problem.fun, D, problem.LB, problem.UB); %#ok<ASGLU>
elapsed = toc;

curve = gfs(1:min(NFEs, numel(gfs)));
if isempty(curve)
    curve = best_curve_from_values(CE(1:NFEs,2));
end

% the final best objective value and corresponding x
[bestF, idx] = min(hf);
bestX = hx(idx,:);

% keep the original output 
raw = struct('hx', hx, 'hf', hf, 'NFEs', NFEs, 'MaxFEs', MaxFEs, 'CE', CE, 'gfs', gfs);
% shared result format
result = make_result('TSDDEO', problemName, D, runIndex, bestF, bestX, curve, elapsed, raw, cfg);
end

function cleanup_path(oldPath, oldDir)
path(oldPath);
cd(oldDir);
end
