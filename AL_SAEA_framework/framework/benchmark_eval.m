function y = benchmark_eval(problemName, x, benchmarkRoot)
% Evaluate one benchmark. Supports one row or many rows.
% For CEC05 functions call benchmarks/CEC05/benchmark_func.m directly, and
% remember variables between calls to benchmark_eval, so that 
% the CEC persistent data is not reset at every single function evaluation inefficiently.

persistent lastProblem lastD

if nargin < 3 || isempty(benchmarkRoot)
    frameworkRoot = fileparts(fileparts(mfilename('fullpath')));
    benchmarkRoot = fullfile(frameworkRoot, 'benchmarks');
end

oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
addpath(fullfile(benchmarkRoot, 'funcname'));
addpath(fullfile(benchmarkRoot, 'CEC05'));
cd(fullfile(benchmarkRoot, 'CEC05'));

problemName = char(problemName);
D = size(x,2);
cecNum = cec05_number(problemName);

if ~isempty(cecNum)
    % benchmark_fun.m also declares global initial_flag
    % so both refer to the same variable
    global initial_flag

    % if this is the first call/problem changed/dimension changed
    % then reset benchmark_func that stores loaded data internally
    if isempty(lastProblem) || ~strcmp(lastProblem, problemName) || lastD ~= D
        clear benchmark_func
        initial_flag = 0;
        lastProblem = problemName;
        lastD = D;
    end
    y = benchmark_func(x, cecNum); % directly call for CEC05 functions
else
    y = feval(problemName, x);
end

y = y(:);
if size(x,1) == 1
    y = y(1);
end
end

function num = cec05_number(problemName)
switch problemName
    case {'CEC05_f10', 'CEC05_F10'}
        num = 10;
    case {'CEC05_f16', 'CEC05_F16'}
        num = 16;
    case {'CEC05_f19', 'CEC05_F19'}
        num = 19;
    otherwise
        num = [];
end
end
