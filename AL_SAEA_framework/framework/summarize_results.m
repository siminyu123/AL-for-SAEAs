function summaryTable = summarize_results(results)
% Make one row per completed run.

if isempty(results)
    summaryTable = table();
    return;
end

n = numel(results);
algorithm = strings(n,1);
problem = strings(n,1);
D = zeros(n,1);
run = zeros(n,1);
bestF = zeros(n,1);
NFE = zeros(n,1);
time = zeros(n,1);
wallTimeSeconds = zeros(n,1);
reused = false(n,1);

for i = 1:n
    r = results{i};

    algorithm(i) = string(r.algorithm);
    problem(i) = string(r.problem);
    D(i) = r.D;
    run(i) = r.run;
    bestF(i) = r.bestF;
    NFE(i) = r.NFE;

    if isfield(r, 'time')
        time(i) = r.time;
    else
        time(i) = NaN;
    end
    
    % For new runs, wallTimeSeconds should be the more consistent one. 
    % For old reused results, it may fall back to time.
    if isfield(r, 'wallTimeSeconds')
        wallTimeSeconds(i) = r.wallTimeSeconds;
    elseif isfield(r, 'time')
        wallTimeSeconds(i) = r.time;
    else
        wallTimeSeconds(i) = NaN;
    end

    if isfield(r, 'reused')
        reused(i) = logical(r.reused);
    end
end

summaryTable = table(algorithm, problem, D, run, bestF, NFE, ...
    time, wallTimeSeconds, reused);

summaryTable = sortrows(summaryTable, {'algorithm','problem','D','run'});
end