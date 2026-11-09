function result = make_result(algorithm, problemName, D, runIndex, bestF, bestX, curve, elapsed, raw, cfg)
% Put all algorithm outputs into the same struct.

if nargin < 10
    cfg = struct();
end

curve = curve(:)';

result = struct();
result.algorithm = string(algorithm);
result.problem = string(problemName);
result.D = D;
result.run = runIndex;
result.bestF = bestF;
result.bestX = bestX;
result.curve = curve;
result.NFE = numel(curve);
result.time = elapsed;
result.raw = raw;
result.created = string(datestr(now));

if isfield(cfg, 'maxFEs')
    result.maxFEs = cfg.maxFEs;
end
if isfield(cfg, 'seedBase')
    result.seedBase = cfg.seedBase;
end
if isfield(cfg, 'al')
    result.al = cfg.al;
end
end
