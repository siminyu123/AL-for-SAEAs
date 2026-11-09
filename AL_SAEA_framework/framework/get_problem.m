function problem = get_problem(problemName, D, benchmarkRoot)
% Build one problem handle using the shared benchmark folder.
% return a struct. 
if nargin < 3 || isempty(benchmarkRoot)
    frameworkRoot = fileparts(fileparts(mfilename('fullpath')));
    benchmarkRoot = fullfile(frameworkRoot, 'benchmarks');
end

funcDir = fullfile(benchmarkRoot, 'funcname');
cecDir = fullfile(benchmarkRoot, 'CEC05');

% Add the benchmark folders here because CEC05 functions load data files.
addpath(funcDir);
addpath(cecDir);

problemName = char(problemName);
[xmin, xmax] = variable_domain(problemName);
problem.name = problemName;
problem.D = D;
problem.LB = xmin * ones(1, D);
problem.UB = xmax * ones(1, D);
problem.fun = @(x) benchmark_eval(problemName, x, benchmarkRoot);
problem.benchmarkRoot = benchmarkRoot;
end
