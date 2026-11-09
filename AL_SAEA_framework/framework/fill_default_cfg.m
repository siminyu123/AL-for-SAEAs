function cfg = fill_default_cfg(cfg)
% Add default fields for the main setting, unless the main script specifies

if ~isfield(cfg, 'frameworkRoot')
    cfg.frameworkRoot = fileparts(fileparts(mfilename('fullpath')));
end
if ~isfield(cfg, 'resultRoot')
    cfg.resultRoot = fullfile(cfg.frameworkRoot, 'results');
end
if ~isfield(cfg, 'codeRoot')
    cfg.codeRoot = fileparts(cfg.frameworkRoot);
end
if ~isfield(cfg, 'runs')
    cfg.runs = 1;
end
if ~isfield(cfg, 'maxFEs')
    cfg.maxFEs = 1000;
end
if ~isfield(cfg, 'seedBase')
    cfg.seedBase = 20260602;
end
if ~isfield(cfg, 'reuseExisting')
    cfg.reuseExisting = true;
end
if ~isfield(cfg, 'continueOnError')
    cfg.continueOnError = true;
end
if ~isfield(cfg, 'al')
    cfg.al = struct();
end
if ~isfield(cfg.al, 'strategy')
    cfg.al.strategy = 'hybrid';
end
if ~isfield(cfg.al, 'alpha')
    cfg.al.alpha = 0.35;
end
if ~isfield(cfg.al, 'maxStage1PerIter')
    cfg.al.maxStage1PerIter = 1;
end
if ~isfield(cfg.al, 'stage2PoolTopK')
    cfg.al.stage2PoolTopK = 20;
end
% Defaults for SA-MPSO AL variants.
% These values affect experiment results and are logged in conditions.txt.
if ~isfield(cfg, 'samps_al')
    cfg.samps_al = struct();
end
if ~isfield(cfg.samps_al, 'pickRatio')
    cfg.samps_al.pickRatio = 0.5;
end
if ~isfield(cfg.samps_al, 'verbose')
    cfg.samps_al.verbose = false;
end
if ~isfield(cfg.samps_al, 'stageVerbose')
    cfg.samps_al.stageVerbose = false;
end
if ~isfield(cfg.samps_al, 'stageLogEvery')
    cfg.samps_al.stageLogEvery = 1;
end
if ~isfield(cfg.samps_al, 'com1TopPredRatio')
    cfg.samps_al.com1TopPredRatio = 0.5;
end
if ~isfield(cfg.samps_al, 'com1PredWeight')
    cfg.samps_al.com1PredWeight = 0.8;
end
if ~isfield(cfg.samps_al, 'com1UncWeight')
    cfg.samps_al.com1UncWeight = 0.2;
end
if ~isfield(cfg.samps_al, 'releaseEnabled')
    cfg.samps_al.releaseEnabled = true;
end
if ~isfield(cfg.samps_al, 'releasePatience')
    cfg.samps_al.releasePatience = 5;
end
if ~isfield(cfg.samps_al, 'releaseMinNFEFraction')
    cfg.samps_al.releaseMinNFEFraction = 0.5;
end
if ~isfield(cfg.samps_al, 'releasePickRatio')
    cfg.samps_al.releasePickRatio = 1.0;
end
if ~isfield(cfg.samps_al, 'ccbSwitchFraction')
    cfg.samps_al.ccbSwitchFraction = 0.7;
end
if ~isfield(cfg.samps_al, 'adaptSwitchFraction')
    cfg.samps_al.adaptSwitchFraction = 0.7;
end
if ~isfield(cfg.samps_al, 'adaptPatience')
    cfg.samps_al.adaptPatience = 4;
end
if ~isfield(cfg.samps_al, 'adaptBlockLength')
    cfg.samps_al.adaptBlockLength = 1;
end
if ~isfield(cfg.samps_al, 'adaptImproveTol')
    cfg.samps_al.adaptImproveTol = 1e-3;
end
% Q-learning defaults for SA_MPSO_AL_Q_BCOV and SA_MPSO_AL_Q_STAGE_BCOV.
if ~isfield(cfg.samps_al, 'qAlpha')
    cfg.samps_al.qAlpha = 0.2;
end
if ~isfield(cfg.samps_al, 'qGamma')
    cfg.samps_al.qGamma = 0.8;
end
if ~isfield(cfg.samps_al, 'qEpsilon')
    cfg.samps_al.qEpsilon = 0.2;
end
if ~isfield(cfg.samps_al, 'qEpsilonDecay')
    cfg.samps_al.qEpsilonDecay = 0.995;
end
if ~isfield(cfg.samps_al, 'qEpsilonMin')
    cfg.samps_al.qEpsilonMin = 0.05;
end
if ~isfield(cfg.samps_al, 'qLocalMinNFEFraction')
    cfg.samps_al.qLocalMinNFEFraction = 0.3;
end
if ~isfield(cfg.samps_al, 'qMaxConsecutiveLocalFails')
    cfg.samps_al.qMaxConsecutiveLocalFails = 2;
end
if ~isfield(cfg.samps_al, 'qStagnationPatience')
    cfg.samps_al.qStagnationPatience = 4;
end
if ~isfield(cfg.samps_al, 'qDiversityThreshold')
    cfg.samps_al.qDiversityThreshold = 0.05;
end
if ~isfield(cfg.samps_al, 'qNoImprovePenalty')
    cfg.samps_al.qNoImprovePenalty = 0.01;
end
if ~isfield(cfg.samps_al, 'qLocalFailPenalty')
    cfg.samps_al.qLocalFailPenalty = 0.02;
end

if ~isfield(cfg, 'plot')
    cfg.plot = struct();
end
if ~isfield(cfg.plot, 'enabled')
    cfg.plot.enabled = true;
end
if ~isfield(cfg.plot, 'statistic')
    cfg.plot.statistic = 'median';
end
if ~isfield(cfg.plot, 'saveFig')
    cfg.plot.saveFig = true;
end
if ~isfield(cfg.plot, 'savePng')
    cfg.plot.savePng = true;
end
if ~isfield(cfg.plot, 'visible')
    cfg.plot.visible = 'off';
end

if ~exist(cfg.resultRoot, 'dir')
    mkdir(cfg.resultRoot);
end
end
