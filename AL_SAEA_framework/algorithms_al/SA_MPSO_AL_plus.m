function [bestF, bestX, curve, raw] = SA_MPSO_AL_plus(FUN, c, bd, bu, maxFES, alOptions)
% main AL addition file for SAMPSO. 
% Only Status 1 has AL adaptation.
% Status 2 trust-region local search is kept unchanged.
%
% Status 1 AL version:
%   Collect the proposed candidates from active subswarms.
%   Evaluate a part(here half) of them, selected by one AL strategy.
%
% Strategies:
%   'A' : low predicted objective + archive distance.
%   'B' : low predicted objective + local-error-based uncertainty.
%   'AB'   : quota split between ERR and DIST.
%   'ABOR' : alternate full half-budget selection between ERR and DIST.
%   'COM1' : weighted committee. First keep only top-predicted
%            candidates, then select by weighted mean prediction + disagreement.
%   'COV'  : distance is measured to both archive and already selected batch points.
%   'BCOV'   : quota split between ERR and COV.
%   'BCOVOR' : alternate whole selected batch between COV and ERR.
%   'COVCOM1'    : quota split between COM1 and COV.
%   'COVCOM1OR'  : alternate whole selected batch between COV and COM1.
%   'BCOVADAPT'   : adaptive ERR/COV switching after Status-1 stagnation.
%   'ABADAPT'     : adaptive ERR/DIST switching after Status-1 stagnation.
%   'COVCOM1ADAPT': adaptive COM1/COV switching after Status-1 stagnation.

% Inputs:
%   FUN     : objective function handle
%   c       : dimension
%   bd, bu  : scalar lower/upper bounds
%   maxFES  : exact evaluation budget
%   alOptions.strategy : one of the strategies above.
%
% Note that this function expects original SA-MPSO helper functions on the path.

%% Initialization
warning('off');

if nargin < 6 || isempty(alOptions)
    alOptions = struct();
end
if ~isfield(alOptions, 'strategy'); alOptions.strategy = 'A'; end
if ~isfield(alOptions, 'pickRatio'); alOptions.pickRatio = 0.5; end
if ~isfield(alOptions, 'verbose'); alOptions.verbose = false; end
if ~isfield(alOptions, 'stageVerbose'); alOptions.stageVerbose = false; end
if ~isfield(alOptions, 'stageLogEvery'); alOptions.stageLogEvery = 1; end

% COM1 parameters: keep only top-predicted candidates first, then use a
% prediction-dominant weighted committee score.
if ~isfield(alOptions, 'com1TopPredRatio'); alOptions.com1TopPredRatio = 0.5; end
if ~isfield(alOptions, 'com1PredWeight'); alOptions.com1PredWeight = 0.8; end
if ~isfield(alOptions, 'com1UncWeight'); alOptions.com1UncWeight = 0.2; end

% Adaptive strategy parameters. These are used only by BCOVADAPT, ABADAPT,
% and COVCOM1ADAPT. adaptImproveTol defines a meaningful improvement so
% tiny numerical decreases do not reset the stagnation counter.
if ~isfield(alOptions, 'adaptPatience'); alOptions.adaptPatience = 4; end
if ~isfield(alOptions, 'adaptBlockLength'); alOptions.adaptBlockLength = 1; end
if ~isfield(alOptions, 'adaptImproveTol'); alOptions.adaptImproveTol = 1e-3; end

strategy = upper(char(alOptions.strategy));


wPred = 0.7;
wDist = 0.3;
wUnc  = 0.3;
localErrorK = 5;

iterl = 200;
nl = 5*c;
npl = 100;

if c >= 30
    N = 100;
else
    N = 5*c;
end
if nargin < 5 || isempty(maxFES)
    maxFES = 1000;
end
maxFES = max(maxFES, N);

BU = repmat(bu,1,c); %#ok<NASGU>
BD = repmat(bd,1,c); %#ok<NASGU>


% Initial exact evaluations
POP = initialize_pop(N,c,bu,bd);
obj = eval_rows(FUN, POP);
n = N;
bound = [bd,bu]; %#ok<NASGU>
X = POP;

% Initial archive. Population and real objective. 
Data = [POP,obj];

% Local-error archive: one error value for each row of Data.
% Initial samples have no previous surrogate prediction, so their error is 0.
archiveErr = zeros(size(Data,1), 1);

% Affinity propagation clustering 
slst = AP(X);
nSwarm = size(slst,2);
citr = zeros(nSwarm, 1);
Pbestx = zeros(n, c);
Pbestf = zeros(n, 1);
Gbestx = zeros(nSwarm, c);
Gbestf = zeros(nSwarm, 1);
f = zeros(n, 1);
v = zeros(n, c);

for j = 1:nSwarm
    h = [];
    for i = 1:size(slst{j},2)
        h(i) = obj(slst{j}(i),:); %#ok<AGROW>
        f(slst{j}(i)) = h(i);
        Pbestx(slst{j}(i),:) = X(slst{j}(i),:);
        Pbestf(slst{j}(i)) = h(i);
        v(slst{j}(i),:) = bu - (bu - bd)*rand(1, c);
    end
    Gbestf(j) = min(h);
    Gbestx(j,:) = X(slst{j}(find(h == min(h), 1)),:);
end

Roverlap = 0.6;
Rexcl = 0.5*(1/nSwarm)*(bu - bd)/(nSwarm^(1/c));
condition = zeros(nSwarm,1);
Record = [];
StepNext = 1;
a0 = 0;
curve = best_curve_from_values(Data(:,end));

alLog = struct();
alLog.strategy = strategy;
alLog.pickRatio = alOptions.pickRatio;
alLog.status1PoolSizes = [];
alLog.status1PickedSizes = [];
alLog.status1NFEs = [];
alLog.status1SelectedSwarms = {};
alLog.status1Scores = {};
alLog.status1SubStrategy = {};
% Base strategy used in each Status-1 selection call.
alLog.status1BaseStrategy = strings(0,1);
alLog.status1EffectivePickRatio = [];
status1Counter = 0;
status1NoImproveCount = 0;
mainIter = 0;
stageLog = struct('iter', {}, 'NFE_before', {}, 'NFE_after', {}, ...
                  'stage', {}, 'nextStage', {}, ...
                  'bestBefore', {}, 'bestAfter', {}, 'improved', {}, ...
                  'status1Pool', {}, 'status1Picked', {}, 'Rexcl', {}, ...
                  'status1NoImproveBefore', {}, ...
                  'effectivePickRatio', {}, 'status1BaseStrategy', {}, ...
                  'relativeImprovement', {}, 'meaningfulImprovement', {});


%% Main loop
while size(Data,1) < maxFES
    mainIter = mainIter + 1;
    StepCur = StepNext;
    nfeBeforeIter = size(Data,1);
    bestBeforeIter = min(Data(:,c+1));
    status1PoolThisIter = NaN;
    status1PickedThisIter = NaN;
    effectivePickRatioThisIter = NaN;
    status1NoImproveBeforeThisIter = status1NoImproveCount;
    status1BaseStrategyThisIter = "";

    switch StepCur
        case 1
            % Status 1: global surrogate-assisted multi-swarm PSO.
            % Global_search builds a global RBF using Data and uses it to move
            % the subswarms. It returns one candidate for each active subswarm
            % whose surrogate-updated Gbest changed.
            [Exactly,condition,citr,slst,X, f, v, Pbestx, Pbestf,~,state] = ...
                Global_search(Data,bu,bd,condition,slst,n,maxFES,citr,X, f, v, Pbestx, Pbestf, Gbestx, Gbestf);

        case 2
            % Status 2: keep original SA-MPSO trust-region local search.
            Pl = sortrows(Data,c+1);
            meanX = Pl(1,:);
            bul = meanX(:,1:c) + Rexcl;
            bul(bul > bu) = bu;
            bdl = meanX(:,1:c) - Rexcl;
            bdl(bdl < bd) = bd;

            Pl = unique(Pl,'rows');
            Dlocal = Pl;
            duplicateIdx = [];
            for i = 1:size(Dlocal,1)
                distance = sum(abs(Pl(:,1:c)-repmat(Pl(i,1:c),size(Pl,1),1)).^2,2).^(1/2);
                near = find(distance < 0.001);
                near(near==i) = [];
                duplicateIdx = [duplicateIdx; near]; %#ok<AGROW>
            end
            Pl(unique(duplicateIdx),:) = [];
            distance = sum(abs(Pl(:,1:c)-repmat(meanX(:,1:c),size(Pl,1),1)).^2,2).^(1/2);
            [sortedDistance, order] = sortrows(distance,1); 
            inside = find(sortedDistance < Rexcl);
            if size(Pl,1) < nl
                Datal = Pl;
            elseif length(inside) < nl
                Datal = Pl(order(1:nl),:);
            else
                Datal = Pl(inside,:);
            end

            [gbestxf, gbestf, gbest] = CSO_LRA(Datal,bul,bdl,npl,iterl,meanX, nl,meanX);
    end

    switch StepCur
        case 1
            minData = min(Data(:,c+1));

            if ~isempty(Exactly)
                activeStateIdx = find(state == 1);

                % Select only a subset of Status-1 candidates using one AL rule.
                status1Counter = status1Counter + 1;

                % Adaptive variants are converted to their current base rule. 
                pickRatioThisIter = min(max(alOptions.pickRatio, 0), 1);
                if pickRatioThisIter <= 0
                    pickRatioThisIter = 0.5;
                end

                switch strategy
                    case 'BCOVADAPT'
                        baseStrategy = adaptive_pair_rule('B', 'COV', status1NoImproveCount, alOptions);
                    case 'ABADAPT'
                        baseStrategy = adaptive_pair_rule('B', 'A', status1NoImproveCount, alOptions);
                    case 'COVCOM1ADAPT'
                        baseStrategy = adaptive_pair_rule('COM1', 'COV', status1NoImproveCount, alOptions);
                    otherwise
                        baseStrategy = strategy;
                end

                effectivePickRatioThisIter = pickRatioThisIter;
                status1BaseStrategyThisIter = string(baseStrategy);

                [selectedLocalIdx, selectedScores, selectedSubStrategy] = select_status1_candidates( ...
                    baseStrategy, Exactly(:,1:c), Data, archiveErr, pickRatioThisIter, ...
                    wPred, wDist, wUnc, localErrorK, status1Counter, ...
                    alOptions.com1TopPredRatio, alOptions.com1PredWeight, alOptions.com1UncWeight);

                Exactly = Exactly(selectedLocalIdx,:);
                selectedSwarmIdx = activeStateIdx(selectedLocalIdx);

                remaining = maxFES - size(Data,1);
                if size(Exactly,1) > remaining
                    Exactly = Exactly(1:remaining,:);
                    selectedSwarmIdx = selectedSwarmIdx(1:remaining);
                    selectedScores = selectedScores(1:remaining);
                    selectedSubStrategy = selectedSubStrategy(1:remaining);
                end

                status1PoolThisIter = numel(activeStateIdx);
                status1PickedThisIter = size(Exactly,1);

                alLog.status1PoolSizes(end+1,1) = numel(activeStateIdx); 
                alLog.status1PickedSizes(end+1,1) = size(Exactly,1); 
                alLog.status1NFEs(end+1,1) = size(Data,1); 
                alLog.status1SelectedSwarms{end+1,1} = selectedSwarmIdx(:)'; 
                alLog.status1Scores{end+1,1} = selectedScores(:)'; 
                alLog.status1SubStrategy{end+1,1} = selectedSubStrategy(:)'; 
                alLog.status1BaseStrategy(end+1,1) = string(baseStrategy); 
                alLog.status1EffectivePickRatio(end+1,1) = pickRatioThisIter; 

                if alOptions.verbose
                    fprintf('SA-MPSO-AL-%s Status 1: selected %d / %d candidates, pickRatio %.2f.\n', ...
                        strategy, size(Exactly,1), numel(activeStateIdx), pickRatioThisIter);
                end

                if ~isempty(Exactly)
                    % Prediction before exact evaluation, for local-error.
                    predBefore = predict_status1_global_model(Exactly(:,1:c));

                    % Exact expensive evaluations.
                    exactlyFit = eval_rows(FUN, Exactly(:,1:c));
                    Exactly(:,c+1) = exactlyFit;

                    % Store prediction errors of newly evaluated points.
                    newErr = relative_prediction_error(predBefore, exactlyFit);
                    archiveErr = [archiveErr; newErr(:)]; %#ok<AGROW>

                    % Append to archive and curve.
                    Data = [Data; Exactly(:,1:c+1)]; %#ok<AGROW>
                    curve = update_curve(curve, Exactly(:,c+1));

                    % Update Gbest of the selected swarms using exact values.
                    bestx = Gbestx;
                    bestf = Gbestf;
                    bestx(selectedSwarmIdx,:) = Exactly(:,1:c);
                    bestf(selectedSwarmIdx,:) = Exactly(:,c+1);
                    improved = bestf < Gbestf;
                    Gbestx(improved,:) = bestx(improved,:);
                    Gbestf(improved,:) = bestf(improved,:);

                    % Original diversity-maintenance scheme.
                    [condition, slst, Gbestx, Gbestf] = condition_detectation(X, condition, slst, Roverlap, Rexcl, Gbestx, Gbestf, Pbestf);
                    indexc = find(condition==2);
                    for i = 1:size(indexc,1)
                        DataD = Data;
                        idx = randperm(size(DataD,1),size(slst{indexc(i)},2));
                        Dr = DataD(idx',:);
                        X(slst{indexc(i)},:) = Dr(:,1:c);
                        f(slst{indexc(i)},:) = Dr(:,c+1);
                        Pbestx(slst{indexc(i)},:) = Dr(:,1:c);
                        Pbestf(slst{indexc(i)},:) = Dr(:,c+1);
                        Gbestf(indexc(i),:) = min(Dr(:,c+1));
                        [~, a2] = min(Dr(:,c+1));
                        Gbestx(indexc(i),:) = Dr(a2,1:c);
                        for j = 1:size(slst{indexc(i)},2)
                            v(slst{indexc(i)}(j),:) = bu - (bu - bd)*rand(1, c);
                        end
                        condition(indexc(i)) = 0;
                    end
                end
            else
                status1PoolThisIter = 0;
                status1PickedThisIter = 1;
                effectivePickRatioThisIter = 1.0;

                % Original fallback: if no active candidate is returned, evaluate
                % the particle with the best surrogate value.
                [~,indexf] = min(f);
                Exactly = X(indexf,:);

                predBefore = f(indexf); % the surrogate-predicted value currently stored for this particle.
                Exactly(:,c+1) = eval_rows(FUN, Exactly(:,1:c));

                archiveErr = [archiveErr; relative_prediction_error(predBefore, Exactly(:,c+1))]; %#ok<AGROW>
                Data = [Data; Exactly(:,1:c+1)]; %#ok<AGROW>
                curve = update_curve(curve, Exactly(:,c+1));
            end

            if min(Data(:,c+1)) < minData
                StepNext = 1;
            else
                StepNext = 2;
                D1 = sortrows(Data,c+1);
                if length(D1) >= 5*c
                    D1 = D1(1:5*c,:);
                end
                [~,xmin] = min(D1(:,c+1));
                Xmin = D1(xmin,1:c);
                [~,xmax] = max(D1(:,c+1));
                Xmax = D1(xmax,1:c);
                Rexcl = norm(Xmin-Xmax)/2;
            end

        case 2
            % Status 2 is unchanged, except that local-surrogate prediction error is also stored. 
            if ~isempty(gbest) && size(Data,1) < maxFES
                gbest(:,c+1) = eval_rows(FUN, gbest(:,1:c));

                % This is a Status-2 local trust-region prediction error, not a
                % Status-1 global model error.  For local-error uncertainty in
                % Status 1, keep the row length aligned but mark this error unknown.
                archiveErr = [archiveErr; NaN(size(gbest(:,c+1)))]; %#ok<AGROW>

                a = find(condition==0);
                if ~isempty(a)
                    gbesta = Gbestx(a,:); gbestaf = Gbestf(a,:);
                    D1 = repmat(gbest(:,1:c),size(a,1),1);
                    distance1 = sum(((D1 - gbesta).^2),2).^0.5;
                    [~,b1] = min(distance1);
                    if gbest(:,c+1) < gbestaf(b1,:)
                        Gbestx(a(b1),:) = gbest(:,1:c);
                        Gbestf(a(b1),:) = gbest(:,c+1);
                    end
                end
                Record = [Record; gbest]; %#ok<AGROW>
                if gbest(:,c+1) < min(Data(:,c+1))
                    StepNext = 2;
                    ro=(meanX(:,c+1)-gbest(:,c+1))/(gbestxf - gbestf-10^(-20));
                    es = 1;
                    if norm(meanX(:,1:c)-gbest(:,1:c)) >= Rexcl
                        es = 2;
                    end
                    % Update trust region radius 
                    if ro<0.25
                        Rexcl=0.25*Rexcl;
                    elseif ro>0.75
                        Rexcl=es*Rexcl;
                    end
                else
                    StepNext = 1;
                end
                Data=[Data;gbest(:,1:c+1)]; %#ok<AGROW>
                curve = update_curve(curve, gbest(:,c+1));
            else
                StepNext = 2;
            end
            a0 = a0 + 1;
            if a0 < 1
                StepNext = 2;
            else
                a0 = 0;
            end
    end

    bestAfterIter = min(Data(:,c+1));
    nfeAfterIter = size(Data,1);
    improvedIter = bestAfterIter < bestBeforeIter;

    % Use meaningful relative improvement to define stagnation for adaptive
    % strategies.  Tiny numerical improvements should not reset the stagnation
    % counter, otherwise adaptive switching may be too sensitive to noise.
    relativeImprovementThisIter = (bestBeforeIter - bestAfterIter) / max(abs(bestBeforeIter), 1e-12);
    meaningfulImprovementThisIter = relativeImprovementThisIter > alOptions.adaptImproveTol;

    % Count consecutive Status-1 iterations without meaningful improvement.
    % Adaptive variants use this count in the next Status-1 call.
    if StepCur == 1
        if meaningfulImprovementThisIter
            status1NoImproveCount = 0;
        else
            status1NoImproveCount = status1NoImproveCount + 1;
        end
    end

    stageLog(end+1).iter = mainIter; %#ok<AGROW>
    stageLog(end).NFE_before = nfeBeforeIter;
    stageLog(end).NFE_after = nfeAfterIter;
    stageLog(end).stage = StepCur;
    stageLog(end).nextStage = StepNext;
    stageLog(end).bestBefore = bestBeforeIter;
    stageLog(end).bestAfter = bestAfterIter;
    stageLog(end).improved = improvedIter;
    stageLog(end).status1Pool = status1PoolThisIter;
    stageLog(end).status1Picked = status1PickedThisIter;
    stageLog(end).Rexcl = Rexcl;
    stageLog(end).status1NoImproveBefore = status1NoImproveBeforeThisIter;
    stageLog(end).effectivePickRatio = effectivePickRatioThisIter;
    stageLog(end).status1BaseStrategy = status1BaseStrategyThisIter;
    stageLog(end).relativeImprovement = relativeImprovementThisIter;
    stageLog(end).meaningfulImprovement = meaningfulImprovementThisIter;

    if alOptions.stageVerbose && mod(mainIter-1, max(1, alOptions.stageLogEvery)) == 0
        fprintf(['SA-MPSO-AL-%s iter %d | NFE %d -> %d | Status %d -> %d | ' ...
                 'best %.4e -> %.4e | improved %d | pool %.0f picked %.0f | ' ...
                 'pickRatio %.2f noImpBefore %d | relImp %.2e meaningful %d | Rexcl %.3e\n'], ...
                strategy, mainIter, nfeBeforeIter, nfeAfterIter, StepCur, StepNext, ...
                bestBeforeIter, bestAfterIter, improvedIter, ...
                status1PoolThisIter, status1PickedThisIter, effectivePickRatioThisIter, ...
                status1NoImproveBeforeThisIter, ...
                relativeImprovementThisIter, meaningfulImprovementThisIter, Rexcl);
    end
end

[bestF, idx] = min(Data(:,c+1));
bestX = Data(idx,1:c);
raw = struct();
raw.Data = Data;
raw.Record = Record;
raw.slst = slst;
raw.condition = condition;
raw.archiveErr = archiveErr;
raw.alLog = alLog;
raw.stageLog = stageLog;
end


%% AL selection functions
function baseStrategy = adaptive_pair_rule(defaultStrategy, fallbackStrategy, status1NoImproveCount, alOptions)
% Return defaultStrategy normally. After adaptPatience no-improvement calls,
% use fallbackStrategy for adaptBlockLength Status-1 calls, then return to
% defaultStrategy for one call before repeating the cycle if stagnation continues.

patience = max(1, round(alOptions.adaptPatience));
blockLen = max(1, round(alOptions.adaptBlockLength));

if status1NoImproveCount < patience
    baseStrategy = defaultStrategy;
else
    k = status1NoImproveCount - patience;
    cycleLen = blockLen + 1;
    if mod(k, cycleLen) < blockLen
        baseStrategy = fallbackStrategy;
    else
        baseStrategy = defaultStrategy;
    end
end
end


function [selectedIdx, selectedScores, selectedSubStrategy] = select_status1_candidates(strategy, candX, Data, archiveErr, pickRatio, wPred, wDist, wUnc, localErrorK, status1Counter, com1TopPredRatio, com1PredWeight, com1UncWeight)
% Select a subset of Status-1 candidates. candX has one row for each active
% subswarm candidate returned by Global_search.

nCand = size(candX,1);
if nCand == 0
    selectedIdx = [];
    selectedScores = [];
    selectedSubStrategy = strings(0,1);
    return;
end

nPick = max(1, ceil(pickRatio * nCand));
nPick = min(nPick, nCand);

switch upper(strategy)
    case 'A'
        % Prediction + archive distance.
        scoreA = score_status1_A(candX, Data, wPred, wDist);
        [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreA}, nPick, "A");

    case 'B'
        % Prediction + local-error uncertainty.
        scoreB = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK);
        [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreB}, nPick, "B");


    case 'AB'
        % Quota split between B and A.
        scoreA = score_status1_A(candX, Data, wPred, wDist);
        scoreB = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK);
        nB = floor(nPick / 2);
        nA = nPick - nB;
        [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreB, scoreA}, [nB, nA], ["B", "A"]);

    case 'ABOR'
        % Alternate whole selected batch between A and B.
        scoreA = score_status1_A(candX, Data, wPred, wDist);
        scoreB = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK);
        if mod(status1Counter, 2) == 1
            [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreA}, nPick, "A");
        else
            [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreB}, nPick, "B");
        end


    case 'COM1'
        % Guarded committee, first keep top predicted candidates,
        % then select by prediction-dominant committee score.
        [scoreMean, scoreUnc] = score_status1_COM(candX, Data);
        [selectedIdx, selectedScores, selectedSubStrategy] = select_status1_COM1(scoreMean, scoreUnc, nPick, com1TopPredRatio, com1PredWeight, com1UncWeight);

    case 'COV'
        % Guarded batch coverage.
        [selectedIdx, selectedScores, selectedSubStrategy] = greedy_coverage_select(candX, Data, nPick, wPred, wDist);

    case 'BCOV'
        % Quota split between B and COV. B is selected first, then COV fills
        % the remaining quota while avoiding redundancy with B-selected points.
        scoreB = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK);
        nB = floor(nPick / 2);
        if nB > 0
            [idxB, scoreSelB, tagB] = quota_select(nCand, {scoreB}, nB, "B");
        else
            idxB = [];
            scoreSelB = [];
            tagB = strings(0,1);
        end
        nCOV = nPick - numel(idxB);
        [idxCOV, scoreSelCOV, tagCOV] = greedy_coverage_select(candX, Data, nCOV, wPred, wDist, idxB);
        selectedIdx = [idxB; idxCOV];
        selectedScores = [scoreSelB; scoreSelCOV];
        selectedSubStrategy = [tagB; tagCOV];

    case 'BCOVOR'
        % Alternate whole selected batch between COV and B.
        if mod(status1Counter, 2) == 1
            [selectedIdx, selectedScores, selectedSubStrategy] = greedy_coverage_select(candX, Data, nPick, wPred, wDist);
        else
            scoreB = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK);
            [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, {scoreB}, nPick, "B");
        end

    case 'COVCOM1'
        % Quota split between COM1 and COV.
        [scoreMean, scoreUnc] = score_status1_COM(candX, Data);
        nCOM1 = ceil(nPick / 2);
        nCOV = nPick - nCOM1;
        [idxCOM1, scoreSelCOM1, tagCOM1] = select_status1_COM1(scoreMean, scoreUnc, nCOM1, com1TopPredRatio, com1PredWeight, com1UncWeight);
        [idxCOV, scoreSelCOV, tagCOV] = greedy_coverage_select(candX, Data, nCOV, wPred, wDist, idxCOM1);
        selectedIdx = [idxCOM1; idxCOV];
        selectedScores = [scoreSelCOM1; scoreSelCOV];
        selectedSubStrategy = [tagCOM1; tagCOV];

    case 'COVCOM1OR'
        % Alternate whole selected batch between COV and COM1.
        if mod(status1Counter, 2) == 1
            [selectedIdx, selectedScores, selectedSubStrategy] = greedy_coverage_select(candX, Data, nPick, wPred, wDist);
        else
            [scoreMean, scoreUnc] = score_status1_COM(candX, Data);
            [selectedIdx, selectedScores, selectedSubStrategy] = select_status1_COM1(scoreMean, scoreUnc, nPick, com1TopPredRatio, com1PredWeight, com1UncWeight);
        end

    otherwise
        error('Unknown SA-MPSO AL strategy: %s', strategy);
end
end

function score = score_status1_A(candX, Data, wPred, wDist)
% A: low predicted objective + archive distance.
pred = predict_status1_global_model(candX);
predScore = normalize_to_01(-pred);
dist = min(pdist2(candX, Data(:,1:end-1)), [], 2);
distScore = normalize_to_01(dist);
score = wPred * predScore + wDist * distScore;
end

function score = score_status1_B(candX, Data, archiveErr, wPred, wUnc, localErrorK)
% B: low predicted objective + local Status-1 model-error uncertainty.
pred = predict_status1_global_model(candX);
predScore = normalize_to_01(-pred);
localErr = local_error_uncertainty(candX, Data(:,1:end-1), archiveErr, localErrorK);
uncScore = normalize_to_01(localErr);
score = wPred * predScore + wUnc * uncScore;
end


function [scoreMean, scoreUnc] = score_status1_COM(candX, Data)
% Build a three-model RBF committee and convert its prediction
% mean and disagreement into candidate scores.
% Model 1 is the current cubic RBF from Global_search. Models 2 and 3 are
% Gaussian RBFs with different widths. Their disagreement estimates surrogate uncertainty. 

trainX = Data(:,1:end-1);
trainY = Data(:,end);

predCubic = predict_status1_global_model(candX);

try
    predG1 = gaussian_rbf_predict(trainX, trainY, candX, 1.0);
catch
    predG1 = predCubic;
end

try
    predG2 = gaussian_rbf_predict(trainX, trainY, candX, 2.0);
catch
    predG2 = predCubic;
end

committeePred = [predCubic(:), predG1(:), predG2(:)];
committeePred(~isfinite(committeePred)) = NaN;

% If a model failed for a candidate, replace NaN by cubic prediction so that
% the committee remains numerically safe.
for j = 1:size(committeePred,2)
    bad = ~isfinite(committeePred(:,j));
    committeePred(bad,j) = predCubic(bad);
end

mu = mean(committeePred, 2);
sigma = std(committeePred, 0, 2);
mu(~isfinite(mu)) = predCubic(~isfinite(mu));
sigma(~isfinite(sigma)) = 0;

scoreMean = normalize_to_01(-mu);
scoreUnc = normalize_to_01(sigma);
end

function [selectedIdx, selectedScores, selectedSubStrategy] = select_status1_COM1(scoreMean, scoreUnc, nPick, topPredRatio, predWeight, uncWeight)
% guarded committee selection.
% Step 1: Only candidates in the top x% by predicted quality are eligible for uncertainty-based selection.
% Step 2: Rank weighted score with prediction-dominant weighting.

nCand = numel(scoreMean);
if nCand == 0
    selectedIdx = [];
    selectedScores = [];
    selectedSubStrategy = strings(0,1);
    return;
end

nPick = min(max(1, nPick), nCand);
topPredRatio = min(max(topPredRatio, 0), 1);
if topPredRatio <= 0
    nEligible = nPick;
else
    nEligible = max(nPick, ceil(topPredRatio * nCand));
end
nEligible = min(nEligible, nCand);

scoreMean = scoreMean(:);
scoreUnc = scoreUnc(:);
scoreMean(~isfinite(scoreMean)) = -inf;
scoreUnc(~isfinite(scoreUnc)) = 0;

[~, predOrder] = sort(scoreMean, 'descend');
eligibleIdx = predOrder(1:nEligible);

predWeight = max(predWeight, 0);
uncWeight = max(uncWeight, 0);
weightSum = predWeight + uncWeight;
predWeight = predWeight / weightSum;
uncWeight = uncWeight / weightSum;

combinedScore = predWeight * scoreMean(eligibleIdx) + uncWeight * scoreUnc(eligibleIdx);
combinedScore(~isfinite(combinedScore)) = -inf;

[sortedScores, orderLocal] = sort(combinedScore, 'descend');
chosenLocal = orderLocal(1:nPick);
selectedIdx = eligibleIdx(chosenLocal);
selectedScores = sortedScores(1:nPick);
selectedSubStrategy = repmat("COM1", nPick, 1);
end

function pred = gaussian_rbf_predict(trainX, trainY, candX, spreadFactor)
% Fit and predict a Gaussian RBF using the same rbfcreate/rbfinterp utilities
% used by the original SA-MPSO code.

if isempty(candX)
    pred = [];
    return;
end

[nTrain, dimTrain] = size(trainX);
rangeVec = max(trainX, [], 1) - min(trainX, [], 1);
positiveRange = rangeVec(rangeVec > 0);
if nTrain <= 1 || dimTrain <= 0 || isempty(positiveRange)
    const = 1;
else
    replacement = median(positiveRange);
    rangeVec(rangeVec <= 0) = replacement;
    logConst = (sum(log(rangeVec)) - log(nTrain)) / dimTrain;
    const = exp(logConst);
    if ~isfinite(const) || const <= 0
        const = replacement;
    end
end
const = const * spreadFactor;
if ~isfinite(const) || const <= 0
    const = 1;
end

model = rbfcreate(trainX', trainY', ...
    'RBFFunction', 'gaussian', ...
    'RBFConstant', const);

pred = rbfinterp(candX', model);
pred = pred(:);
end

function [selectedIdx, selectedScores, selectedSubStrategy] = greedy_coverage_select(candX, Data, nPick, wPred, wDist, preSelectedIdx)
% Guarded greedy batch coverage.
% After one candidate is selected, the next candidate's distance is measured
% to both the original archive and the candidates already selected in this same Status-1 batch.
%
% preSelectedIdx is used by BCOV. It blocks candidates already
% selected by the B quota but includes them as reference points for the
% following coverage selections.

if nargin < 6 || isempty(preSelectedIdx)
    preSelectedIdx = [];
end

nCand = size(candX,1);
archiveX = Data(:,1:end-1);

pred = predict_status1_global_model(candX);
predScoreAll = normalize_to_01(-pred);

remaining = true(nCand,1); % for marking chosen ones
preSelectedIdx = preSelectedIdx(:); % ensure column vectors
preSelectedIdx = preSelectedIdx(preSelectedIdx >= 1 & preSelectedIdx <= nCand);
remaining(preSelectedIdx) = false; % avoid selecting the B-selected ones

selectedIdx = [];
selectedScores = [];
selectedSubStrategy = strings(0,1);

selectedX = candX(preSelectedIdx,:);

for t = 1:nPick
    availableIdx = find(remaining);
    if isempty(availableIdx)
        break;
    end

    if isempty(selectedX)
        referenceX = archiveX;
    else
        referenceX = [archiveX; selectedX]; 
    end

    % Coverage distance to archive + already selected batch points.
    dist = min(pdist2(candX(availableIdx,:), referenceX), [], 2);
    distScore = normalize_to_01(dist);

    score = wPred * predScoreAll(availableIdx) + wDist * distScore;
    score(~isfinite(score)) = -inf;

    [bestScore, bestLocal] = max(score);
    chosen = availableIdx(bestLocal);

    selectedIdx = [selectedIdx; chosen]; %#ok<AGROW>
    selectedScores = [selectedScores; bestScore]; %#ok<AGROW>
    selectedSubStrategy = [selectedSubStrategy; "COV"]; %#ok<AGROW>
    selectedX = [selectedX; candX(chosen,:)]; %#ok<AGROW>

    remaining(chosen) = false;
end

if isempty(selectedIdx) && isempty(preSelectedIdx)
    selectedIdx = 1;
    selectedScores = 0;
    selectedSubStrategy = "COV";
end
end


function [selectedIdx, selectedScores, selectedSubStrategy] = quota_select(nCand, scoreList, quotaList, tagList)
% Greedy quota selection without replacement. Each quota is applied after
% removing candidates selected by previous quotas.
selectedIdx = [];
selectedScores = [];
selectedSubStrategy = strings(0,1);
remaining = true(nCand,1);

for q = 1:numel(scoreList)
    quota = quotaList(q);
    if quota <= 0 || ~any(remaining)
        continue;
    end

    score = scoreList{q}(:);
    score(~isfinite(score)) = -inf;

    availableIdx = find(remaining);
    [sortedScores, orderLocal] = sort(score(availableIdx), 'descend');
    nThis = min(quota, numel(availableIdx));
    chosen = availableIdx(orderLocal(1:nThis));

    selectedIdx = [selectedIdx; chosen(:)]; %#ok<AGROW>
    selectedScores = [selectedScores; sortedScores(1:nThis)]; %#ok<AGROW>
    selectedSubStrategy = [selectedSubStrategy; repmat(string(tagList(q)), nThis, 1)]; %#ok<AGROW>

    remaining(chosen) = false;
end
end

function localErr = local_error_uncertainty(candX, archiveX, archiveErr, k)
% Estimate uncertainty at candX from nearby archive points' previous Status 1
% global model errors.
%
% Points close to archive samples where the global model was inaccurate
% receive high local-error uncertainty. Unknown errors are ignored.
archiveErr = archiveErr(:);

nArchiveX = size(archiveX,1);
nArchiveE = numel(archiveErr);
nArchive = min(nArchiveX, nArchiveE);

if nArchive == 0 || isempty(candX)
    localErr = zeros(size(candX,1),1);
    return;
end

archiveX = archiveX(1:nArchive,:);
archiveErr = archiveErr(1:nArchive);

% Ignore unknown errors for NN calculation
validErr = isfinite(archiveErr);
if ~any(validErr)
    localErr = zeros(size(candX,1),1);
    return;
end

archiveX = archiveX(validErr,:);
archiveErr = archiveErr(validErr);

k = min(k, size(archiveX,1));
Dmat = pdist2(candX, archiveX);
[nearD, nearIdx] = sort(Dmat, 2, 'ascend');
nearD = nearD(:,1:k);
nearIdx = nearIdx(:,1:k);
nearErr = reshape(archiveErr(nearIdx(:)), size(nearIdx));

% Inverse distance weighting
W = 1 ./ max(nearD, 1e-12); % for numerical stability 
localErr = sum(W .* nearErr, 2) ./ max(sum(W,2), 1e-12); 
localErr(~isfinite(localErr)) = 0;
end

function pred = predict_status1_global_model(X)
% Predict with the global RBF model currently stored in the original SA-MPSO
% global variable coefC. Global_search creates this model immediately before
% candidate selection.
if isempty(X)
    pred = [];
else
    pred = YCRBF(X);
    pred = pred(:);
end
end


% Utilities
function y = eval_rows(FUN, X)
% Evaluate the objective for each row of X.
y = zeros(size(X,1),1);
for i = 1:size(X,1)
    y(i) = FUN(X(i,:));
end
end

function curve = update_curve(curve, values)
% Append best-so-far values after exact evaluations.
values = values(:)';
if isempty(curve)
    current = inf;
else
    current = curve(end);
end
for i = 1:numel(values)
    current = min(current, values(i));
    curve(end+1) = current; %#ok<AGROW>
end
end

function err = relative_prediction_error(pred, truth)
% Relative surrogate prediction error used by the local-error AL.
pred = pred(:);
truth = truth(:);
err = abs(truth - pred) ./ max(max(abs(truth), abs(pred)), 1e-12);
err(~isfinite(err)) = 0;
end

function z = normalize_to_01(x)
% Normalize finite values to [0,1] and set infinite values to zero.
x = x(:);
finiteMask = isfinite(x);
z = zeros(size(x));
if ~any(finiteMask)
    return;
end
xmin = min(x(finiteMask));
xmax = max(x(finiteMask));
if xmax <= xmin
    z(finiteMask) = 0.5;
else
    z(finiteMask) = (x(finiteMask) - xmin) ./ (xmax - xmin);
end
z(~finiteMask) = 0;
end
