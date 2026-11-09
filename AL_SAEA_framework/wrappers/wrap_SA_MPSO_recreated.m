function result = wrap_SA_MPSO_recreated(problemName, D, runIndex, cfg)
% Run the recreated SA-MPSO code on one problem.
% The called algorithm is adapted from a recreated version of SA_MPSO at
% https://github.com/SZU-AdvTech-2022/060-Surrogate-assisted-Multipopulation-Particle-Swarm-Optimizer-for-High-dimensional-Expensive-Optim. 

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

% check if the problem has the same lower bound/upper bound for every
% decision variable. Because the called function only accepts a single
% (scalar) lower/upper bound. 
if any(abs(problem.LB - problem.LB(1)) > 0) || any(abs(problem.UB - problem.UB(1)) > 0)
    error('SA-MPSO recreated supports scalar bounds only.');
end

% run the adapted version that takes input and returns also a best-so-far curve.
tic;
[bestF, bestX, curve, rawCore] = SA_MPSO_recreated_core(problem.fun, D, problem.LB(1), problem.UB(1), cfg.maxFEs);
elapsed = toc;

raw = rawCore;
result = make_result('SA_MPSO_recreated', problemName, D, runIndex, bestF, bestX, curve, elapsed, raw, cfg);
end

function cleanup_path(oldPath, oldDir)
path(oldPath);
cd(oldDir);
end
