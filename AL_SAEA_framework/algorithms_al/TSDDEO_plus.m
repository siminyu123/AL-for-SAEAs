function [hx,hf,NFEs,MaxFEs,CE,gfs,alLog] = TSDDEO_plus(FUN,D,LB,UB,alOptions)
% main AL addition file file for TSDDEO. 
%
% AL is inserted only in Stage 1.2 PSO surrogate prescreening:
%   Generate the new swarm by the PSO equations.
%   Keep candidates whose surrogate prediction is better than their pbest.
%   Remove repeated candidates.
%   Select one candidate for exact evaluation using the requested AL rule.
%
% Supported alOptions.strategy:
%   'DIST'       : prediction + archive distance
%   'COM'        : 3-RBF committee with different spreads, prediction dominant
%                  but consider uncertainty too.
%   'DISTCOM'    : alternating DIST and COM, one Stage 1.2 call each.
%  Note: compare to the original TSDDEO codes, some helper functions are
%  added for repetitive blocks. 

if nargin < 5 || isempty(alOptions)
    alOptions = struct();
end
alOptions = fill_tsddeo_plus_defaults(alOptions);

%% Initialization
NFEs = 0; 
MaxFEs = alOptions.MaxFEs; % maximum number of exact evaluation
ps = 50;                   % population size
CE = zeros(MaxFEs,2);      % archive the exact fitness
sn1 = 1; 
gen = 1;
show = 0;

if D < 100
    initial_sample_size = 100;
else
    initial_sample_size = 150;
end
initial_sample_size = min(initial_sample_size, MaxFEs);
gfs = zeros(1,fix(MaxFEs/sn1)); % sampling point according to fitness evaluation for plotting the convergence curve.  
                                % fix() rounds each element of X to the nearest integer toward zero

alLog = init_al_log(alOptions.strategy);
stage12Counter = 0;

% Initial Latin hypercube samples.
% generate matrix of size (initial_sample_size)*D, scaled to the bounds
% [LB,UB], by first creating matrix with values in (0,1) with lhsdesign 
% and mapping from unit cube to bound box. 
sam = repmat(LB,initial_sample_size,1) + ...
      (repmat(UB,initial_sample_size,1)-repmat(LB,initial_sample_size,1)) .* ...
      lhsdesign(initial_sample_size,D);
fit = zeros(1, initial_sample_size);

for i = 1:initial_sample_size
    if NFEs >= MaxFEs
        break;
    end
    fit(i) = FUN(sam(i,:));
    NFEs = NFEs + 1;
    CE(NFEs,:) = [NFEs, fit(i)];
    gfs = update_gfs(gfs, CE, NFEs, sn1);
end
sam = sam(1:NFEs,:);
fit = fit(1:NFEs);

% Build database, sort hf and reorder hx to match the order
hx = sam;
hf = fit;
[hf, sidx] = sort(hf);
hx = hx(sidx,:);

% Training sample numbers
gs = initial_sample_size;
ls = 50;

% First-stage PSO parameters
cc = [2.05 2.05];
iwt = 0.7298;

VRmax = UB;
VRmin = LB;
mv = 0.5 * (VRmax - VRmin);
VRmin_ = VRmin;
VRmax_ = VRmax;
VRmin = repmat(VRmin,ps,1);
VRmax = repmat(VRmax,ps,1);
Vmin = repmat(-mv,ps,1);
Vmax = -Vmin;
vel = Vmin + 2 .* Vmax .* rand(ps,D);    % initialize the velocity of the particles
pos = hx(1:ps,:);
e = hf(1:ps);                            % initialize position and fitness
pbest = pos;
pbestval = e;                            % initialize the pbest and the pbest's fitness value
[gbestval,gbestid] = min(pbestval);
gbest = pbest(gbestid,:);                % initialize the gbest and the gbest's fitness value
gbestrep = repmat(gbest,ps,1);
besty = 1e200;
bestp = zeros(1,D);

% Second stage parameters
F = 0.5;
CR = 0.5;

% Main loop
while NFEs < MaxFEs
    [ghf,id] = sort(hf);
    %% Stage 1: global RBF + PSO prescreening.
    if NFEs < 300
        nTrain = min(gs, numel(ghf));
        ghf = ghf(1:nTrain);
        ghx = hx(id(1:nTrain),:);
        modelFUN = build_rbf_model(ghx, ghf, D, 1.0);
        
        % Record the old best position and fitness
        besty_old = besty;
        bestp_old = bestp;

        % Stage 1.1: find the surrogate optimum by SLPSO.
        maxgen = 50*D;
        minerror = 1e-8;
        [bestp, ~] = SLPSO(D, maxgen, modelFUN, minerror, ghx);

        % Exact evaluate the surrogate optimum if it has not been evaluated.
        if NFEs < MaxFEs && ~is_repeated(bestp, hx)
            besty = FUN(bestp);
            NFEs = NFEs + 1;
            hx = [hx; bestp]; %#ok<AGROW>
            hf = [hf, besty]; %#ok<AGROW>
            [hf,sidx] = sort(hf);
            hx = hx(sidx,:);
            CE(NFEs,:) = [NFEs, besty];
            gfs = update_gfs(gfs, CE, NFEs, sn1);

            % If this new point is good enough, rebuild the RBF model.
            if ghf(end) > besty
                [tmpf,tmpid] = sort(hf);
                nTrain = min(gs, numel(tmpf));
                ghf = tmpf(1:nTrain);
                ghx = hx(tmpid(1:nTrain),:);
                modelFUN = build_rbf_model(ghx, ghf, D, 1.0);
            end
        else
            % If bestp is repeated, use its known exact value.
            [tf, idxKnown] = ismember(bestp, hx, 'rows');
            if tf
                besty = hf(idxKnown);
            end
        end
        % Record the new best position and fitness of surrogate
        besty_new = besty;
        bestp_new = bestp;
        % Update model optimum
        if besty_new < besty_old
            besty = besty_new;
            bestp = bestp_new;
            bestprep = repmat(bestp_new,ps,1);
        else
            besty = besty_old;
            bestp = bestp_old;
            bestprep = repmat(bestp_old,ps,1);
        end

        if besty < gbestval
            [~,ip,~] = intersect(pbest,gbest,'rows');
            pbest(ip,:) = bestp;
            pbestval(ip) = besty;
            gbestrep = bestprep;
        end

        % Generate new swarm by PSO operators.
        aa = cc(1).*rand(ps,D).*(pbest-pos) + cc(2).*rand(ps,D).*(gbestrep-pos);
        vel = iwt .* (vel + aa);
        vel = (vel>Vmax).*Vmax + (vel<=Vmax).*vel; % Make sure each component of vel lies in [Vmin,Vmax]
        vel = (vel<Vmin).*Vmin + (vel>=Vmin).*vel;
        pos = pos + vel;
        % random reset out-of-bounds positions near the lower/upper bound
        % to encourage exploration near boundaries 
        pos = ((pos>=VRmin)&(pos<=VRmax)).*pos ...
            +(pos<VRmin).*(VRmin+0.25.*(VRmax-VRmin).*rand(ps,D)) ...
            +(pos>VRmax).*(VRmax-0.25.*(VRmax-VRmin).*rand(ps,D));

        % Stage 1.2: surrogate prescreening.
        % Keep those whose predicted value improves their pbest.
        predAll = modelFUN(pos);
        predAll = predAll(:);
        candidx = find(predAll < pbestval(:));
        posPool = pos(candidx,:);
        predPool = predAll(candidx);

        % Remove already evaluated candidates, but do not skip the whole iteration.
        [posPool, keepIdx] = remove_repeated_candidates(posPool, hx);
        candidx = candidx(keepIdx);
        predPool = predPool(keepIdx);

        poolSize = size(posPool,1);
        stage12Counter = stage12Counter + 1; % for interchanging if combine two strategies
        selectedCount = 0;
        subStrategy = "none";
        selectedPred = NaN;
        selectedFit = NaN;
        bestBeforeStage12 = min(hf);
        % Select with AL strategies
        if poolSize > 0 && NFEs < MaxFEs
            effectiveStrategy = resolve_effective_strategy(alOptions.strategy, stage12Counter);

            nPick = min([alOptions.stage1Pick, poolSize, MaxFEs - NFEs]);
            [pickLocal, ~, subStrategy] = select_stage12_candidates( ...
                effectiveStrategy, posPool, predPool, hx, hf(:), ghx, ghf(:), D, alOptions, nPick);

            for kk = 1:numel(pickLocal)
                if NFEs >= MaxFEs
                    break;
                end
                localIdx = pickLocal(kk);
                xCand = posPool(localIdx,:);
                predCand = predPool(localIdx);
                fCand = FUN(xCand);
                NFEs = NFEs + 1;
                hx = [hx; xCand]; %#ok<AGROW>  % update history database 
                hf = [hf, fCand]; %#ok<AGROW>  
                [hf,sidx] = sort(hf);
                hx = hx(sidx,:);
                CE(NFEs,:) = [NFEs, fCand];
                gfs = update_gfs(gfs, CE, NFEs, sn1);

                kp = candidx(localIdx);
                if fCand < pbestval(kp)        % update pbest
                    pbest(kp,:) = xCand;
                    pbestval(kp) = fCand;
                end

                selectedCount = selectedCount + 1;
                selectedPred = predCand;
                selectedFit = fCand;
            end
        end
        
        bestAfterStage12 = min(hf);
        relImpStage12 = (bestBeforeStage12 - bestAfterStage12) / max(abs(bestBeforeStage12), 1e-12);

        alLog = append_stage12_log(alLog, gen, NFEs, alOptions.strategy, subStrategy, ...
            poolSize, selectedCount, selectedPred, selectedFit, ...
            bestBeforeStage12, bestAfterStage12, relImpStage12);
        % Update gbest
        [gbestval,tmp] = min(pbestval);
        gbest = pbest(tmp,:);
        gbestrep = repmat(gbest,ps,1);
        bestfit = min([gbestval,besty]); %#ok<NASGU>
        if alOptions.verbose
            fprintf('TSDDEO_plus-%s | iter %d | NFE %d | best %.4e | pool %d picked %d | %s\n', ...
                char(alOptions.strategy), gen, NFEs, min(hf), poolSize, selectedCount, char(subStrategy));
        end
        gen = gen + 1;

    %% Stage 2: fixed TS-DDEO behavior, no AL inserted here.
    else
        NP = 50;

        VRmin2 = repmat(VRmin_,NP,1);
        VRmax2 = repmat(VRmax_,NP,1);

        % Fixed: sort before selecting the best NP data as population P.
        [hf,sidx] = sort(hf);
        hx = hx(sidx,:);

        P = hx(1:NP,:);
        % Generate n trial vectors using DE/rand/1
        U = DEoperating(P,NP,D,hx,F,CR,VRmax2,VRmin2);

        % 2.1 global surrogate screening
        % build global surrogate model
        [ghf,id] = sort(hf);
        nTrain = min(gs, numel(ghf));
        ghx = hx(id(1:nTrain),:);
        ghf = ghf(1:nTrain);
        modelFUN = build_rbf_model(ghx, ghf, D, 1.0);

        fitnessModel = modelFUN(U);
        [~,sidx] = sort(fitnessModel);
        sam = U(sidx,:);
        candidate_position = first_nonrepeated_candidate(sam, hx);
        if NFEs < MaxFEs && ~isempty(candidate_position)
            [hx,hf,NFEs,CE,gfs] = evaluate_and_store(candidate_position,FUN,hx,hf,NFEs,CE,gfs,sn1,MaxFEs,show,1);
        end

        if NFEs >= MaxFEs
            break;
        end

        % 2.2 local surrogate search
        % Obtain one candidate by minimizing using DE in the local region
        [lhf,id] = sort(hf);
        nLocal = min(ls, numel(lhf));
        lhx = hx(id(1:nLocal),:);
        lhf = lhf(1:nLocal);
        LocalModelFUN = build_rbf_model(lhx, lhf, D, 1.0);

        maxgen = 50*D;
        minerror = 1e-8;
        [candidate_position,~] = DE(D,maxgen,LocalModelFUN,minerror,lhx);

        if NFEs < MaxFEs && ~is_repeated(candidate_position, hx)
            [hx,hf,NFEs,CE,gfs] = evaluate_and_store(candidate_position,FUN,hx,hf,NFEs,CE,gfs,sn1,MaxFEs,show,2);
        end

        if NFEs >= MaxFEs
            break;
        end

        % 2.3 full crossover
        % Select g best data as population P;
        % Sampling one candidate by FC(P, global surrogate);
        % Evaluate the candidate then update DB and surrogate models;
        if rand < 0.2
            ls2 = gs;
            [lhf,id] = sort(hf);
            nCross = min(ls2, numel(lhf));
            lhx = hx(id(1:nCross),:);
            lhf = lhf(1:nCross);
            GlobalModelFUN = build_rbf_model(lhx, lhf, D, 1.0);
            candidate_position = full_crossover(GlobalModelFUN,lhx);

            if NFEs < MaxFEs && ~is_repeated(candidate_position, hx)
                [hx,hf,NFEs,CE,gfs] = evaluate_and_store(candidate_position,FUN,hx,hf,NFEs,CE,gfs,sn1,MaxFEs,show,3);
            end
        end

        gen = gen + 1;
    end
end

CE = CE(1:min(NFEs,size(CE,1)),:);
gfs = gfs(1:min(NFEs,numel(gfs)));
end

%% Default settings and logging helpers.
function alOptions = fill_tsddeo_plus_defaults(alOptions)
if ~isfield(alOptions, 'strategy'); alOptions.strategy = 'DIST'; end
if ~isfield(alOptions, 'MaxFEs'); alOptions.MaxFEs = 1000; end
if ~isfield(alOptions, 'stage1Pick'); alOptions.stage1Pick = 1; end
if ~isfield(alOptions, 'predWeight'); alOptions.predWeight = 0.7; end
if ~isfield(alOptions, 'distWeight'); alOptions.distWeight = 0.3; end
if ~isfield(alOptions, 'comPredWeight'); alOptions.comPredWeight = 0.7; end
if ~isfield(alOptions, 'comUncWeight'); alOptions.comUncWeight = 0.3; end
if ~isfield(alOptions, 'comSpreadFactors'); alOptions.comSpreadFactors = [0.5 1.0 2.0]; end
if ~isfield(alOptions, 'verbose'); alOptions.verbose = false; end
alOptions.strategy = upper(char(alOptions.strategy));
valid = {'PRED','DIST','COM','DISTCOM'};
if ~any(strcmp(alOptions.strategy, valid))
    error('Unknown TSDDEO_plus strategy: %s', alOptions.strategy);
end
end

function alLog = init_al_log(strategy)
alLog = struct();
alLog.strategy = string(strategy);
alLog.stage12Calls = 0;
alLog.stage12Selections = 0;
alLog.stage12PoolTotal = 0;
alLog.stage12 = struct('iter',{},'NFE_after',{},'strategy',{},'subStrategy',{}, ...
    'poolSize',{},'selectedCount',{},'selectedPred',{},'selectedFit',{}, ...
    'bestBefore',{},'bestAfter',{},'relImprovement',{});
end

function alLog = append_stage12_log(alLog, iter, NFE_after, strategy, subStrategy, poolSize, selectedCount, selectedPred, selectedFit, bestBefore, bestAfter, relImp)
alLog.stage12Calls = alLog.stage12Calls + 1;
alLog.stage12Selections = alLog.stage12Selections + selectedCount;
alLog.stage12PoolTotal = alLog.stage12PoolTotal + poolSize;
row = struct();
row.iter = iter;
row.NFE_after = NFE_after;
row.strategy = string(strategy);
row.subStrategy = string(subStrategy);
row.poolSize = poolSize;
row.selectedCount = selectedCount;
row.selectedPred = selectedPred;
row.selectedFit = selectedFit;
row.bestBefore = bestBefore;
row.bestAfter = bestAfter;
row.relImprovement = relImp;
alLog.stage12(end+1,1) = row;
end

%% Stage 1.2 AL selection helpers
function effectiveStrategy = resolve_effective_strategy(strategy, stageCounter)
% Odd Stage-1.2 calls use DIST and even calls use COM. The other used directly.
strategy = upper(char(strategy));
effectiveStrategy = strategy;

switch strategy
    case 'DISTCOM'
        if mod(stageCounter,2) == 1
            effectiveStrategy = 'DIST';
        else
            effectiveStrategy = 'COM';
        end
    case {'PRED','DIST','COM'}
    otherwise
        error('Unknown TSDDEO_plus strategy: %s', strategy);
end
end

function [selectedIdx, selectedScores, selectedSubStrategy] = select_stage12_candidates(strategy, candX, pred, archiveX, archiveF, trainX, trainY, D, al, nPick) %#ok<INUSD>
% Select candidates from the Stage 1.2 screened pool. The pool contains 
% only particles predicted to improve their personal best and the AL
% rule further filters which one is worth exact evaluation.
strategy = upper(char(strategy));
nCand = size(candX,1);
nPick = min(max(1, round(nPick)), nCand);

switch strategy
    case 'DIST'
        score = score_DIST(candX, pred, archiveX, al.predWeight, al.distWeight);
        [selectedIdx, selectedScores] = topk_score(score, nPick);
        selectedSubStrategy = repmat("DIST", numel(selectedIdx), 1);

    case 'COM'
        score = score_COM(candX, pred, trainX, trainY, D, al);
        [selectedIdx, selectedScores] = topk_score(score, nPick);
        selectedSubStrategy = repmat("COM", numel(selectedIdx), 1);

    otherwise
        error('Unknown TSDDEO_plus Stage-1.2 strategy: %s', strategy);
end
end

function score = score_DIST(candX, pred, archiveX, wPred, wDist)
% DIST balances prediction and archive distance. Prediction is kept
% dominant by the default 0.7/0.3 weighting.
predScore = normalize01(-pred(:));
if isempty(archiveX)
    distScore = zeros(size(predScore));
else
    dist = min(pairwise_distances(candX, archiveX), [], 2);
    distScore = normalize01(dist);
end
score = wPred * predScore + wDist * distScore;
score(~isfinite(score)) = -inf;
end

function score = score_COM(candX, predBase, trainX, trainY, D, al)
% COM builds three RBFs with different spreads and uses their disagreement
% as uncertainty. Candidate quality still dominates by the default 0.7/0.3 weighting.
[mu, sigma] = rbf3_committee_predict(candX, trainX, trainY, D, al.comSpreadFactors, predBase);
predScore = normalize01(-mu(:));
uncScore = normalize01(sigma(:));
score = al.comPredWeight * predScore + al.comUncWeight * uncScore;
score(~isfinite(score)) = -inf;
end

function [mu, sigma, predMat] = rbf3_committee_predict(candX, trainX, trainY, D, spreadFactors, fallbackPred)
% Use spread-scaled RBFs to estimate committee mean and disagreement.
% If any model fails, fall back to the Stage 1.2 base prediction so that 
% a full iteration is not missed because of one unstable surrogate.
if nargin < 6 || isempty(fallbackPred)
    fallbackPred = zeros(size(candX,1),1);
end
fallbackPred = fallbackPred(:);
nCand = size(candX,1);
spreadFactors = spreadFactors(:)';
if isempty(spreadFactors)
    spreadFactors = [0.5 1.0 2.0];
end
predMat = nan(nCand, numel(spreadFactors));
for j = 1:numel(spreadFactors)
    try
        modelFUN = build_rbf_model(trainX, trainY, D, spreadFactors(j));
        tmpPred = modelFUN(candX);
        predMat(:,j) = tmpPred(:);
    catch
        predMat(:,j) = fallbackPred;
    end
end
for j = 1:size(predMat,2)
    bad = ~isfinite(predMat(:,j));
    predMat(bad,j) = fallbackPred(bad);
end
mu = mean(predMat, 2, 'omitnan');
sigma = std(predMat, 0, 2, 'omitnan');
mu(~isfinite(mu)) = fallbackPred(~isfinite(mu));
sigma(~isfinite(sigma)) = 0;
end


function [idx, sortedScores] = topk_score(score, nPick)
score = score(:);
score(~isfinite(score)) = -inf;
[sortedScores, order] = sort(score, 'descend');
nPick = min(nPick, numel(order));
idx = order(1:nPick);
sortedScores = sortedScores(1:nPick);
end

function y = normalize01(x)
x = x(:);
y = zeros(size(x));
finiteMask = isfinite(x);
if ~any(finiteMask)
    return;
end
xmin = min(x(finiteMask));
xmax = max(x(finiteMask));
if xmax - xmin < 1e-12
    y(finiteMask) = 0.5;
else
    y(finiteMask) = (x(finiteMask) - xmin) ./ (xmax - xmin);
end
y(~finiteMask) = 0;
end

function Dmat = pairwise_distances(A, B)
try
    Dmat = pdist2(A, B);
catch
    AA = sum(A.^2, 2);
    BB = sum(B.^2, 2)';
    Dmat = sqrt(max(AA + BB - 2*(A*B'), 0));
end
end

%% TS-DDEO helper functions to simplify the original structure. 
function modelFUN = build_rbf_model(trainX, trainY, D, spreadFactor)
if nargin < 4 || isempty(spreadFactor)
    spreadFactor = 1.0;
end
trainY = trainY(:)';
N = size(trainX,1);
Dist = pairwise_distances(trainX, trainX);
spr = max(Dist(:)) / max((D*N)^(1/max(D,1)), eps);
spr = spr * spreadFactor;
if ~isfinite(spr) || spr <= 0
    rangeVec = max(trainX, [], 1) - min(trainX, [], 1);
    positiveRange = rangeVec(rangeVec > 0 & isfinite(rangeVec));
    if isempty(positiveRange)
        spr = 1;
    else
        spr = mean(positiveRange) / sqrt(max(D,1));
    end
end
if ~isfinite(spr) || spr <= 0
    spr = 1;
end
spr = max(spr, 1e-12);
net = newrbe(trainX', trainY, spr);
modelFUN = @(x) sim(net,x');
end

function gfs = update_gfs(gfs, CE, NFEs, sn1)
if mod(NFEs,sn1) == 0
    cs1 = NFEs/sn1;
    if cs1 <= numel(gfs)
        gfs(1,cs1) = min(CE(1:NFEs,2));
    end
end
end

function [hx,hf,NFEs,CE,gfs] = evaluate_and_store(candidate_position,FUN,hx,hf,NFEs,CE,gfs,sn1,MaxFEs,show,tag)
if NFEs >= MaxFEs
    return;
end
candidate_fit = FUN(candidate_position);
NFEs = NFEs + 1;
if show
    disp([' candidate_fit=' num2str(candidate_fit) ' point = ' num2str(candidate_position)]);
end
hx = [hx; candidate_position]; 
hf = [hf, candidate_fit]; 
[hf,sidx] = sort(hf);
hx = hx(sidx,:);
CE(NFEs,:) = [NFEs,candidate_fit];
gfs = update_gfs(gfs, CE, NFEs, sn1);
if show && candidate_fit <= hf(1)
    disp(['Best Cost(' num2str(tag) ') = ' num2str(candidate_fit) ' NFE=' num2str(NFEs)]);
end
end

function tf = is_repeated(x, archiveX)
if isempty(x) || isempty(archiveX)
    tf = false;
else
    tf = ~isempty(intersect(archiveX,x,'rows'));
end
end

function candidate = first_nonrepeated_candidate(candidateX, archiveX)
candidate = [];
for i = 1:size(candidateX,1)
    if ~is_repeated(candidateX(i,:), archiveX)
        candidate = candidateX(i,:);
        return;
    end
end
end

function [newX, keepIdx] = remove_repeated_candidates(candidateX, archiveX)
if isempty(candidateX)
    newX = candidateX;
    keepIdx = [];
    return;
end
keep = true(size(candidateX,1),1);
for i = 1:size(candidateX,1)
    if is_repeated(candidateX(i,:), archiveX)
        keep(i) = false;
    end
end
newX = candidateX(keep,:);
keepIdx = find(keep);
end

