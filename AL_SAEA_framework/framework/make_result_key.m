function key = make_result_key(alg, problemName, D, runIndex, cfg)
% Make a filename-safe key for one result, for matching later. 

alg = char(alg);
problemName = char(problemName);
seed = cfg.seedBase + runIndex;

algUpper = upper(alg);

alPart = '';

% For AL3, the algorithm label already stores the test condition,
% like TSDDEO_AL3_warm_s1p2. So old cfg.al.strategy not appended.
if contains(algUpper, 'AL') && ...
        ~startsWith(algUpper, 'TSDDEO_AL3') && ...
        isfield(cfg, 'al')
    alPart = ['_' cfg.al.strategy];
    if isfield(cfg.al, 'alpha')
        alPart = [alPart '_a' num2str(cfg.al.alpha)];
    end
end

key = sprintf('%s_%s_D%d_run%d_FE%d_seed%d%s', ...
    alg, problemName, D, runIndex, cfg.maxFEs, seed, alPart);

key = regexprep(key, '[^a-zA-Z0-9_\-.]', '_');
end
