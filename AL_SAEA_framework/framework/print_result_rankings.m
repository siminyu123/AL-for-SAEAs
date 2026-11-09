function print_result_rankings(summaryTable, testDir)
% Print and save algorithm rankings grouped by problem and dimension.
%
% Ranking rule:
%   Smaller bestF is better. Algorithms with tied ranking values get
%   the same rank using competition ranking, e.g. 1, 1, 3.
%
% If multiple runs: based on mean bestF across runs.

if nargin < 2
    testDir = '';
end

if isempty(summaryTable)
    fprintf('\nNo results to rank because summaryTable is empty.\n');
    return;
end

algCol = string(summaryTable.algorithm);
probCol = string(summaryTable.problem);
DCol = summaryTable.D;
bestFCol = summaryTable.bestF;

problems = unique(probCol, 'stable');

textLines = strings(0, 1);
rankRecords = struct('algorithm', {}, 'problem', {}, 'D', {}, 'rank', {}, 'rankValue', {}, 'runs', {});
% Relative tolerance for treating two ranking values as tied.
% Exact equal results will always tie; the tolerance only protects against
% tiny floating-point formatting/noise differences.
tieRelTol = 1e-20;

textLines(end+1) = "============================================================";
textLines(end+1) = "Ranking by problem and dimension";
textLines(end+1) = "============================================================";

for p = 1:numel(problems)
    problemName = problems(p);
    dims = unique(DCol(probCol == problemName), 'stable');

    for d = 1:numel(dims)
        D = dims(d);

        idxPD = (probCol == problemName) & (DCol == D);
        algs = unique(algCol(idxPD), 'stable');

        rankNames = strings(numel(algs), 1);
        rankValues = zeros(numel(algs), 1);
        rankRuns = zeros(numel(algs), 1);

        for a = 1:numel(algs)
            algName = algs(a);
            idxA = idxPD & (algCol == algName);
            values = bestFCol(idxA);
            values = values(isfinite(values));

            rankNames(a) = algName;
            rankRuns(a) = numel(values);

            if isempty(values)
                rankValues(a) = inf;
            else
                rankValues(a) = median(values);
            end
        end

        [rankValues, order] = sort(rankValues, 'ascend');
        rankNames = rankNames(order);
        rankRuns = rankRuns(order);
        ranks = competition_ranks(rankValues, tieRelTol);

        textLines(end+1) = "";
        textLines(end+1) = sprintf('%s | D = %d', problemName, D);
        textLines(end+1) = "------------------------------------------------------------";

        for r = 1:numel(rankNames)
            if isinf(rankValues(r))
                textLines(end+1) = sprintf('%2d. %-32s   no valid result', ranks(r), rankNames(r));
            else
                textLines(end+1) = sprintf('%2d. %-32s   %.6e   runs=%d', ranks(r), rankNames(r), rankValues(r), rankRuns(r));
            end

            rec = struct();
            rec.algorithm = rankNames(r);
            rec.problem = problemName;
            rec.D = D;
            rec.rank = ranks(r);
            rec.rankValue = rankValues(r);
            rec.runs = rankRuns(r);
            rankRecords(end+1,1) = rec; %#ok<AGROW>
        end

        orderLine = build_tied_order_line(rankNames, ranks);
        textLines(end+1) = orderLine;
    end
end

% Average rank summary across all tested problem-dimension cases.
if ~isempty(rankRecords)
    rankTable = struct2table(rankRecords);
    algsAll = unique(string(rankTable.algorithm), 'stable');

    avgAlg = strings(numel(algsAll),1);
    avgRank = zeros(numel(algsAll),1);
    medRank = zeros(numel(algsAll),1);
    nCases = zeros(numel(algsAll),1);
    nWins = zeros(numel(algsAll),1);

    for a = 1:numel(algsAll)
        algName = algsAll(a);
        idx = string(rankTable.algorithm) == algName & isfinite(rankTable.rankValue);
        ranks = rankTable.rank(idx);
        avgAlg(a) = algName;
        nCases(a) = numel(ranks);
        if isempty(ranks)
            avgRank(a) = inf;
            medRank(a) = inf;
            nWins(a) = 0;
        else
            avgRank(a) = mean(ranks);
            medRank(a) = median(ranks);
            nWins(a) = sum(ranks == 1);
        end
    end

    avgTable = table(avgAlg, avgRank, medRank, nCases, nWins, ...
        'VariableNames', {'algorithm','meanRank','medianRank','nCases','nWins'});
    avgTable = sortrows(avgTable, {'meanRank','medianRank','algorithm'});

    textLines(end+1) = "";
    textLines(end+1) = "============================================================";
    textLines(end+1) = "Average rank across all tested problem-dimension cases";
    textLines(end+1) = "============================================================";

    for r = 1:height(avgTable)
        textLines(end+1) = sprintf('%2d. %-32s   meanRank=%.3f   medianRank=%.3f   cases=%d   wins=%d', ...
            r, avgTable.algorithm(r), avgTable.meanRank(r), avgTable.medianRank(r), avgTable.nCases(r), avgTable.nWins(r));
    end
else
    avgTable = table();
end

textLines(end+1) = "";

fprintf('\n');
for i = 1:numel(textLines)
    fprintf('%s\n', textLines(i));
end

if ~isempty(testDir)
    if ~exist(testDir, 'dir')
        mkdir(testDir);
    end

    txtPath = fullfile(testDir, 'ranking_summary.txt');
    fid = fopen(txtPath, 'w');
    if fid == -1
        warning('Could not open ranking text file for writing: %s', txtPath);
    else
        for i = 1:numel(textLines)
            fprintf(fid, '%s\n', textLines(i));
        end
        fclose(fid);
        fprintf('Saved ranking summary to:\n');
        fprintf('  %s\n', txtPath);
    end

    if ~isempty(avgTable)
        avgPath = fullfile(testDir, 'average_rank_summary.csv');
        try
            writetable(avgTable, avgPath);
            fprintf('Saved average rank summary to:\n');
            fprintf('  %s\n', avgPath);
        catch ME
            warning('Could not save average rank summary CSV: %s', ME.message);
        end
    end
end
end

function ranks = competition_ranks(values, tieRelTol)
% Assign equal rank to tied values using competition ranking.

values = values(:);
n = numel(values);
ranks = zeros(n,1);
if n == 0
    return;
end

currentRank = 1;
ranks(1) = currentRank;
for i = 2:n
    if values_are_tied(values(i), values(i-1), tieRelTol)
        ranks(i) = currentRank;
    else
        currentRank = i;
        ranks(i) = currentRank;
    end
end
end

function tf = values_are_tied(a, b, tieRelTol)
% Treat exact equal values as ties and protect against tiny numerical noise.

if isinf(a) && isinf(b)
    tf = true;
    return;
end
if ~isfinite(a) || ~isfinite(b)
    tf = false;
    return;
end
scale = max([1, abs(a), abs(b)]);
tf = abs(a - b) <= tieRelTol * scale;
end

function orderLine = build_tied_order_line(rankNames, ranks)
% Build an order line that shows tied methods with '=' and rank groups with '>'.

orderLine = "Order: ";
if isempty(rankNames)
    return;
end

for i = 1:numel(rankNames)
    if i == 1
        orderLine = orderLine + rankNames(i);
    else
        if ranks(i) == ranks(i-1)
            orderLine = orderLine + " = " + rankNames(i);
        else
            orderLine = orderLine + " > " + rankNames(i);
        end
    end
end
end

