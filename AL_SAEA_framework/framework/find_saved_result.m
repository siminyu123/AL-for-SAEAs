function result = find_saved_result(cfg, alg, problemName, D, runIndex)
% Look through old test folders and return a matching result if it exists.
% - used when cfg.reuseExisting is set to true
% - select the newest file when multiple exist for the same combination.

result = [];
if ~exist(cfg.resultRoot, 'dir')
    return;
end

% create the key(filename when stored) for the result to be searched
wantedKey = make_result_key(alg, problemName, D, runIndex, cfg);

% first try exact key files
files1 = dir(fullfile(cfg.resultRoot, 'test_*', 'mat', [wantedKey '.mat']));
files2 = dir(fullfile(cfg.resultRoot, 'plot_only_*', 'mat', [wantedKey '.mat']));
files = [files1; files2];

% if multiple exact-key files exist, use the newest one
if ~isempty(files)
    [~, newestIdx] = max([files.datenum]);
    newestFile = files(newestIdx);

    S = load(fullfile(newestFile.folder, newestFile.name));
    if isfield(S, 'result')
        result = S.result;
        return;
    end
end

% fallback: scan all result files and compare fields.
% in case older files were saved with a different key format.
files1 = dir(fullfile(cfg.resultRoot, 'test_*', 'mat', '*.mat'));
files2 = dir(fullfile(cfg.resultRoot, 'plot_only_*', 'mat', '*.mat'));
files = [files1; files2];

matchedFiles = [];

for i = 1:numel(files)
    if contains(files(i).name, 'FAILED')
        continue;
    end

    S = load(fullfile(files(i).folder, files(i).name));
    if ~isfield(S, 'result')
        continue;
    end

    r = S.result;
    if result_matches(r, alg, problemName, D, runIndex, cfg)
        matchedFiles = [matchedFiles; files(i)]; %#ok<AGROW>
    end
end

% if multiple fallback files match, use the newest one
if ~isempty(matchedFiles)
    [~, newestIdx] = max([matchedFiles.datenum]);
    newestFile = matchedFiles(newestIdx);

    S = load(fullfile(newestFile.folder, newestFile.name));
    if isfield(S, 'result')
        result = S.result;
        return;
    end
end
end