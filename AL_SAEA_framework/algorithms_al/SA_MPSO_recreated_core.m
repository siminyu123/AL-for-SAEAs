function [bestF, bestX, curve, raw] = SA_MPSO_recreated_core(FUN, c, bd, bu, maxFES)
% One-problem/one-run conversion of SA_MPSO.m.
% This preserves the structure of the recreated script available at 
% https://github.com/SZU-AdvTech-2022/060-Surrogate-assisted-Multipopulation-Particle-Swarm-Optimizer-for-High-dimensional-Expensive-Optim 
% but replaces hard-coded problem loops by inputs and records a best-so-far curve.
%
% Inputs:
%   FUN: objective function handle, row vector -> scalar
%   c: dimension
%   bd, bu: scalar lower/upper bounds
%   maxFES: exact evaluation budget, counted as rows in Data

warning('off');
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

% Initialize population. The uploaded SA-MPSO initialize_pop expects scalar bounds.
POP = initialize_pop(N,c,bu,bd);
obj = eval_rows(FUN, POP);
n = N;
bound = [bd,bu]; %#ok<NASGU>
X = POP;

% Affinity propagation clustering / subswarms.
slst = AP(X);
citr = zeros(size(slst,2), 1);
Pbestx = zeros(n, c);
Pbestf = zeros(n, 1);
Gbestx = zeros(size(slst,2), c);
Gbestf = zeros(size(slst,2), 1);
f = zeros(n, 1);
v = zeros(n, c);
for j = 1:size(slst,2)
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
Rexcl = 0.5*(1/size(slst,2))*(bu - bd)/(size(slst,2)^(1/c));
condition = zeros(size(slst,2),1);
Data = [POP,obj];
Record = [];
StepNext = 1;
a0 = 0;
curve = best_curve_from_values(Data(:,end));

while size(Data,1) < maxFES
    StepCur = StepNext;
    switch StepCur
        case 1
            [Exactly,condition,citr,slst,X, f, v, Pbestx, Pbestf,~,state] = ...
                Global_search(Data,bu,bd,condition,slst,n,maxFES,citr,X, f, v, Pbestx, Pbestf, Gbestx, Gbestf);
        case 2
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
            [sortedDistance, order] = sortrows(distance,1); %#ok<ASGLU>
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
                remaining = maxFES - size(Data,1);
                activeStateIdx = find(state == 1);
                if size(Exactly,1) > remaining
                    Exactly = Exactly(1:remaining,:);
                    activeStateIdx = activeStateIdx(1:remaining);
                end
                Exactly(:,c+1) = eval_rows(FUN, Exactly(:,1:c));
                Data = [Data; Exactly(:,1:c+1)]; %#ok<AGROW>
                curve = update_curve(curve, Exactly(:,c+1));

                best = Exactly;
                bestx = Gbestx; bestf = Gbestf;
                bestx(activeStateIdx,:) = best(:,1:c);
                bestf(activeStateIdx,:) = best(:,c+1);

                Gbestx((bestf < Gbestf),:) = bestx((bestf < Gbestf),:);
                Gbestf((bestf < Gbestf),:) = bestf((bestf < Gbestf),:);

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
            else
                [~,indexf] = min(f);
                Exactly = X(indexf,:);
                Exactly(:,c+1) = eval_rows(FUN, Exactly(:,1:c));
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
            if ~isempty(gbest) && size(Data,1) < maxFES
                gbest(:,c+1) = eval_rows(FUN, gbest(:,1:c));
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
end

[bestF, idx] = min(Data(:,c+1));
bestX = Data(idx,1:c);
raw = struct('Data', Data, 'Record', Record, 'slst', {slst}, 'condition', condition);
end

function y = eval_rows(FUN, X)
y = zeros(size(X,1),1);
for i = 1:size(X,1)
    y(i) = FUN(X(i,:));
end
end

function curve = update_curve(curve, values)
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
