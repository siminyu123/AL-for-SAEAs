function tf = result_matches(r, alg, problemName, D, runIndex, cfg)
% Decide whether a saved result can be reused for the current setting.

tf = false;
if ~isfield(r, 'algorithm') || ~isfield(r, 'problem') || ~isfield(r, 'D') || ~isfield(r, 'run')
    return;
end
if ~strcmp(char(r.algorithm), char(alg)); return; end
if ~strcmp(char(r.problem), char(problemName)); return; end
if r.D ~= D; return; end
if r.run ~= runIndex; return; end

if isfield(r, 'maxFEs') && r.maxFEs ~= cfg.maxFEs
    return;
end
if isfield(r, 'seedBase') && r.seedBase ~= cfg.seedBase
    return;
end

% For AL variants, also check the important AL settings
% (probably needs changes depending on how AL strategy is defined)
if contains(upper(char(alg)), 'AL') && isfield(r, 'al') && isfield(cfg, 'al')
    if isfield(r.al, 'strategy') && isfield(cfg.al, 'strategy')
        if ~strcmp(char(r.al.strategy), char(cfg.al.strategy)); return; end
    end
    if isfield(r.al, 'alpha') && isfield(cfg.al, 'alpha')
        if abs(r.al.alpha - cfg.al.alpha) > 1e-12; return; end
    end
    if isfield(r.al, 'maxStage1PerIter') && isfield(cfg.al, 'maxStage1PerIter')
        if r.al.maxStage1PerIter ~= cfg.al.maxStage1PerIter; return; end
    end
    if isfield(r.al, 'stage2PoolTopK') && isfield(cfg.al, 'stage2PoolTopK')
        if r.al.stage2PoolTopK ~= cfg.al.stage2PoolTopK; return; end
    end
end

tf = true;
end
