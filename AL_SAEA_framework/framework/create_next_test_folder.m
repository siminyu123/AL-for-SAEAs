function testDir = create_next_test_folder(cfg, prefix)
% Create subfolders like results/test_001, results/test_002, ...

if nargin < 2 || isempty(prefix)
    prefix = 'test';
end
if ~exist(cfg.resultRoot, 'dir')
    mkdir(cfg.resultRoot);
end

items = dir(fullfile(cfg.resultRoot, [prefix '_*']));
% search for the largest number for existing subfolders
maxId = 0;
for i = 1:numel(items)
    if items(i).isdir
        % find text starting with test_ and capture the following digits
        tok = regexp(items(i).name, [prefix '_(\d+)'], 'tokens', 'once');
        if ~isempty(tok)
            maxId = max(maxId, str2double(tok{1}));
        end
    end
end

nextId = maxId + 1;
testDir = fullfile(cfg.resultRoot, sprintf('%s_%03d', prefix, nextId));
mkdir(testDir);
end
