function result = find_saved_result_in_testdir(testDir, cfg, alg, problemName, D, runIndex)
% Find a completed saved result inside one fixed experiment folder.
%
% For resume mode. It does NOT search other test folders.
% If a valid result exists, return it.
% If not, return [] so the experiment will run that case.

result = [];

matDir = fullfile(testDir, 'mat');
if ~exist(matDir, 'dir')
    return;
end

% First try exact filename from the current key rule.
try
    key = make_result_key(alg, problemName, D, runIndex, cfg);
    exactFile = fullfile(matDir, [key '.mat']);

    if exist(exactFile, 'file') == 2
        S = load(exactFile, 'result');
        if isfield(S, 'result') && local_result_matches(S.result, cfg, alg, problemName, D, runIndex)
            result = S.result;
            return;
        end
    end
catch
    % If exact-key checking fails, fall back to scanning the folder.
end

% Fallback:
% scan only this testDir/mat folder.
files = dir(fullfile(matDir, '*.mat'));

matchedFiles = [];

for i = 1:numel(files)
    if contains(files(i).name, 'FAILED', 'IgnoreCase', true)
        continue;
    end

    filePath = fullfile(files(i).folder, files(i).name);

    try
        S = load(filePath, 'result');
    catch
        % Corrupted/incomplete file. Ignore it and rerun that case.
        continue;
    end

    if ~isfield(S, 'result')
        continue;
    end

    if local_result_matches(S.result, cfg, alg, problemName, D, runIndex)
        matchedFiles = [matchedFiles; files(i)]; %#ok<AGROW>
    end
end

% If duplicate matching files exist, use the newest one.
if ~isempty(matchedFiles)
    [~, newestIdx] = max([matchedFiles.datenum]);
    newestFile = matchedFiles(newestIdx);

    S = load(fullfile(newestFile.folder, newestFile.name), 'result');
    result = S.result;
end

end


function ok = local_result_matches(r, cfg, alg, problemName, D, runIndex)
% Case-insensitive matching for resume mode.

ok = true;

if ~isfield(r, 'algorithm') || ~strcmpi(char(r.algorithm), char(alg))
    ok = false;
    return;
end

if ~isfield(r, 'problem') || ~strcmpi(char(r.problem), char(problemName))
    ok = false;
    return;
end

if ~isfield(r, 'D') || r.D ~= D
    ok = false;
    return;
end

if ~isfield(r, 'run') || r.run ~= runIndex
    ok = false;
    return;
end

% Optional checks if these fields exist.
if isfield(r, 'maxFEs') && isfield(cfg, 'maxFEs')
    if r.maxFEs ~= cfg.maxFEs
        ok = false;
        return;
    end
end

if isfield(r, 'seed') && isfield(cfg, 'seedBase')
    expectedSeed = cfg.seedBase + runIndex;
    if r.seed ~= expectedSeed
        ok = false;
        return;
    end
end

% A completed result should have at least bestF and curve.
if ~isfield(r, 'bestF') || isempty(r.bestF)
    ok = false;
    return;
end

if ~isfield(r, 'curve') || isempty(r.curve)
    ok = false;
    return;
end

end