function append_global_log(cfg, testDir)
% Keep one global log to remember what each folder means.

logCsv = fullfile(cfg.resultRoot, 'experiment_log.csv');
logTxt = fullfile(cfg.resultRoot, 'experiment_log.txt');

[~, folderName] = fileparts(testDir);
created = string(datestr(now));
algText = string(strjoin(cfg.algorithms, ', '));
problemText = string(strjoin(cfg.problems, ', '));
dimText = string(mat2str(cfg.dims));
runText = cfg.runs;
maxFEs = cfg.maxFEs;
alStrategy = "";
if isfield(cfg, 'al') && isfield(cfg.al, 'strategy')
    alStrategy = string(cfg.al.strategy);
end

newRow = table(string(folderName), created, algText, problemText, dimText, runText, maxFEs, alStrategy, ...
    'VariableNames', {'folder','created','algorithms','problems','dims','runs','maxFEs','alStrategy'});

if exist(logCsv, 'file') == 2
    old = readtable(logCsv, 'TextType', 'string');
    out = [old; newRow];
else
    out = newRow;
end
writetable(out, logCsv);

fid = fopen(logTxt, 'a');
if fid >= 0
    fprintf(fid, '\n%s\n', folderName);
    fprintf(fid, '  created: %s\n', created);
    fprintf(fid, '  algorithms: %s\n', algText);
    fprintf(fid, '  problems: %s\n', problemText);
    fprintf(fid, '  dims: %s\n', dimText);
    fprintf(fid, '  runs: %d\n', runText);
    fprintf(fid, '  maxFEs: %d\n', maxFEs);
    fprintf(fid, '  alStrategy: %s\n', alStrategy);
    fclose(fid);
end
end
