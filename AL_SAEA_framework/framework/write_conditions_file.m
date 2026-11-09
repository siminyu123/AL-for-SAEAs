function write_conditions_file(cfg, testDir, note)
% Save the settings in a readable text file for reproducibility.

if nargin < 3
    note = '';
end
fid = fopen(fullfile(testDir, 'conditions.txt'), 'w');
if fid < 0
    warning('Could not write conditions.txt');
    return;
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'Experiment folder: %s\n', testDir);
fprintf(fid, 'Created at: %s\n', datestr(now));
fprintf(fid, 'Note: %s\n\n', note);

fprintf(fid, 'Algorithms:\n');
for i = 1:numel(cfg.algorithms)
    fprintf(fid, '  - %s\n', cfg.algorithms{i});
end
fprintf(fid, '\nProblems:\n');
for i = 1:numel(cfg.problems)
    fprintf(fid, '  - %s\n', cfg.problems{i});
end
fprintf(fid, '\nDimensions: %s\n', mat2str(cfg.dims));
fprintf(fid, 'Runs: %d\n', cfg.runs);
fprintf(fid, 'maxFEs: %d\n', cfg.maxFEs);
fprintf(fid, 'seedBase: %d\n', cfg.seedBase);
fprintf(fid, 'reuseExisting: %d\n', cfg.reuseExisting);
fprintf(fid, 'continueOnError: %d\n', cfg.continueOnError);

if isfield(cfg, 'al')
    fprintf(fid, '\nAL settings:\n');
    names = fieldnames(cfg.al);
    for i = 1:numel(names)
        val = cfg.al.(names{i});
        fprintf(fid, '  %s: %s\n', names{i}, value_to_text(val));
    end
end

if isfield(cfg, 'samps_al')
    fprintf(fid, '\nSA-MPSO AL settings (cfg.samps_al):\n');
    names = fieldnames(cfg.samps_al);
    for i = 1:numel(names)
        val = cfg.samps_al.(names{i});
        fprintf(fid, '  %s: %s\n', names{i}, value_to_text(val));
    end
end

if isfield(cfg, 'plot')
    fprintf(fid, '\nPlot settings:\n');
    names = fieldnames(cfg.plot);
    for i = 1:numel(names)
        val = cfg.plot.(names{i});
        fprintf(fid, '  %s: %s\n', names{i}, value_to_text(val));
    end
end
end

function txt = value_to_text(val)
if isnumeric(val) || islogical(val)
    txt = mat2str(val);
elseif ischar(val)
    txt = val;
elseif isstring(val)
    txt = char(val);
else
    txt = '<struct or cell>';
end
end
