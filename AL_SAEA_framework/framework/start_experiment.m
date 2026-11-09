function [results, summaryTable, failureTable, testDir] = start_experiment(cfg)
% Run one experiment setting and save everything in one numbered sub-folder.

cfg = fill_default_cfg(cfg);

% testDir = create_next_test_folder(cfg, 'test');
% Choose experiment folder.
% If cfg.testDir is given, use that folder and append/resume there.
% Otherwise create a new test_xxx folder.
if isfield(cfg, 'testDir') && ~isempty(cfg.testDir)
    testDir = cfg.testDir;
    if ~exist(testDir, 'dir')
        mkdir(testDir);
    end
else
    testDir = create_next_test_folder(cfg, 'test');
end

matDir = fullfile(testDir, 'mat');
if ~exist(matDir, 'dir')
    mkdir(matDir);
end
matDir = fullfile(testDir, 'mat');
figDir = fullfile(testDir, 'figures');
mkdir(matDir);
mkdir(figDir);

write_conditions_file(cfg, testDir, 'Normal run.');
append_global_log(cfg, testDir);

results = {};
failures = {};

for a = 1:numel(cfg.algorithms)
    alg = cfg.algorithms{a};
    for p = 1:numel(cfg.problems)
        problemName = cfg.problems{p};
        for d = 1:numel(cfg.dims)
            D = cfg.dims(d);
            for runIndex = 1:cfg.runs
                key = make_result_key(alg, problemName, D, runIndex, cfg);
                outFile = fullfile(matDir, [key '.mat']);
                % search and reuse results if exist
                if cfg.reuseExisting
                    oldResult = find_saved_result(cfg, alg, problemName, D, runIndex);
                    if ~isempty(oldResult)
                        oldResult.reused = true;
                        results{end+1,1} = oldResult; %#ok<AGROW>
                        result = oldResult; %#ok<NASGU>
                        save(outFile, 'result');
                        fprintf('Reused: %s | %s | D=%d | run=%d\n', alg, problemName, D, runIndex);
                        continue;
                    end
                end

                seed = cfg.seedBase + runIndex;
                rng(seed, 'twister');
                fprintf('\n=== %s | %s | D=%d | run=%d | seed=%d ===\n', alg, problemName, D, runIndex, seed);
                caseTimer = tic;
                caseStartTime = datetime('now');

                try
                    % Resume mode:
                    % only look for completed results inside the current fixed testDir.
                    % This avoids accidentally reusing results from other old test folders.
                    if isfield(cfg, 'resumeFromTestDir') && cfg.resumeFromTestDir
                        oldResult = find_saved_result_in_testdir(testDir, cfg, alg, problemName, D, runIndex);

                        if ~isempty(oldResult)
                            fprintf('RESUME: found existing result, skip %s | %s | D=%d | run=%d\n', ...
                                char(alg), char(problemName), D, runIndex);

                            oldResult.reused = true;
                            results{end+1,1} = oldResult; %#ok<AGROW>
                            continue;
                        end
                    end
                    
                    result = run_one_algorithm(alg, problemName, D, runIndex, cfg);

                    caseElapsed = toc(caseTimer);
                    caseEndTime = datetime('now');

                    result.reused = false;
                    result.key = key;
                    result.seed = seed;

                    % Wall-clock time measured outside the wrapper.
                    result.wallTimeSeconds = caseElapsed;
                    result.startTime = caseStartTime;
                    result.endTime = caseEndTime;

                    results{end+1,1} = result; %#ok<AGROW>
                    save(outFile, 'result');

                    fprintf('Finished: %s | %s | D=%d | run=%d | %.2f sec / %.2f min\n', ...
                        alg, problemName, D, runIndex, caseElapsed, caseElapsed/60);

                    append_timing_log(testDir, alg, problemName, D, runIndex, ...
                        "success", caseElapsed, caseStartTime, caseEndTime, "");

                catch ME
                    caseElapsed = toc(caseTimer);
                    caseEndTime = datetime('now');

                    failure = struct();
                    failure.algorithm = string(alg);
                    failure.problem = string(problemName);
                    failure.D = D;
                    failure.run = runIndex;
                    failure.message = string(ME.message);
                    failure.identifier = string(ME.identifier);
                    failure.key = string(key);

                    failure.wallTimeSeconds = caseElapsed;
                    failure.startTime = caseStartTime;
                    failure.endTime = caseEndTime;

                    failures{end+1,1} = failure; %#ok<AGROW>

                    fprintf('FAILED: %s | %s | D=%d | run=%d after %.2f sec / %.2f min\n', ...
                        alg, problemName, D, runIndex, caseElapsed, caseElapsed/60);
                    fprintf('%s\n', ME.message);

                    append_timing_log(testDir, alg, problemName, D, runIndex, ...
                        "failed", caseElapsed, caseStartTime, caseEndTime, string(ME.message));
                    
                    save(fullfile(matDir, [key '_FAILED.mat']), 'failure', 'ME');

                    if ~cfg.continueOnError
                        rethrow(ME);
                    end
                end
            end
        end
    end
end

summaryTable = summarize_results(results);
failureTable = failures_to_table(failures);

writetable(summaryTable, fullfile(testDir, 'summary.csv'));
if ~isempty(failureTable)
    writetable(failureTable, fullfile(testDir, 'failures.csv'));
end
save(fullfile(testDir, 'all_results.mat'), 'cfg', 'results', 'summaryTable', 'failureTable');

if cfg.plot.enabled
    plot_convergence_curves(results, cfg, figDir);
end
end
