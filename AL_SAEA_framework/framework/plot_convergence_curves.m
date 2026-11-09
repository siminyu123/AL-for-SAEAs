function plot_convergence_curves(results, cfg, figDir)
% Plot one convergence figure for each problem and dimension.
% results: cell array storing result struct from each run. 
% cfg: experiment setting struct.
% figDir: optional, can specify where to save figures. 

if nargin < 3 || isempty(figDir)
    figDir = fullfile(cfg.resultRoot, 'figures');
end
if ~exist(figDir, 'dir')
    mkdir(figDir);
end
if isempty(results)
    warning('No results available for plotting.');
    return;
end

for p = 1:numel(cfg.problems)
    problemName = cfg.problems{p};
    for d = 1:numel(cfg.dims)
        D = cfg.dims(d);
        % one figure for one problem and one dimension
        fig = figure('Visible', cfg.plot.visible); 
        hold on; % multiple curves in the same figure 
        grid on;
        plotted = false; % check at least one algorithm has data
        allY = []; % for all y-values from all algorithms 

        for a = 1:numel(cfg.algorithms)
            alg = cfg.algorithms{a};
            % collect all curves from runs matching combination of
            % this alg+problem+dim
            curves = collect_curves(results, alg, problemName, D);
            if isempty(curves)
                continue;
            end
            % if multiple runs, aggregate by median/mean
            y = aggregate_curves(curves, cfg.plot.statistic);
            x = 1:numel(y);

            % shorten some long internal algorithm names for the legend.
            labelName = display_algorithm_label(alg);
     
            lineColor = algorithm_color(alg, a);
            plot(x, y, 'LineWidth', 1.5, 'Color', lineColor, 'DisplayName', labelName);

            % store y-values as row, later can decide whether log-scale is needed
            allY = [allY, y(:)']; %#ok<AGROW>
            plotted = true;
        end
        
        title(sprintf('%s, D=%d', problemName, D), 'Interpreter', 'none'); % so that _ not treated as subscript
        xlabel('Exact function evaluations');
        ylabel('Best-so-far objective value');
        legend('Location', 'best', 'Interpreter', 'none');
        
        % use log-scale when suitable (decrease by several orders of
        % magnitude), the standard can be adjusted again
        if plotted && ~isempty(allY) && all(allY > 0) && max(allY) / max(min(allY), realmin) > 100
            set(gca, 'YScale', 'log');
        end
        % make sure the figure name is safe without problematic space/,/). 
        % now the name is like ELLIPSOID_30D_median 
        safeName = regexprep(sprintf('%s_%dD_%s', problemName, D, cfg.plot.statistic), ...
                            '[^a-zA-Z0-9_\-.]', '_');
        if plotted
            if isfield(cfg.plot, 'savePng') && cfg.plot.savePng
                saveas(fig, fullfile(figDir, [safeName '.png']));
            end

            if isfield(cfg.plot, 'saveFig') && cfg.plot.saveFig
                savefig(fig, fullfile(figDir, [safeName '.fig']));
            end

            if isfield(cfg.plot, 'savePdf') && cfg.plot.savePdf
                pdfPath = fullfile(figDir, [safeName '.pdf']);
                exportgraphics(fig, pdfPath, 'ContentType', 'vector');
            end
        end
        close(fig);
    end
end
end

function curves = collect_curves(results, alg, problemName, D)
% Collect all convergence curves for one alg+problem+dimension.
curves = {};
targetAlg = upper(char(alg));
targetProblem = char(problemName);
for i = 1:numel(results)
    r = results{i};
    resultAlg = upper(char(r.algorithm));
    resultProblem = char(r.problem);
    if strcmp(resultAlg, targetAlg) && strcmp(resultProblem, targetProblem) && r.D == D
        if isfield(r, 'curve') && ~isempty(r.curve)
            curves{end+1,1} = r.curve(:)'; %#ok<AGROW>
        end
    end
end
end

function y = aggregate_curves(curves, statistic)
% Combine multiple runs into one curve
% Note: if a curve is shorter, pad it using its last value, just in case
% like CAL-SAPSO hard to finish 1000 runs. 

% Get the lengths of each curve(run) and use the longest as common length
lengths = cellfun(@numel, curves);
L = max(lengths);
% Now use matrix to collect curves, one curve one row, and 
% column is exact evaluation
M = nan(numel(curves), L); 
for i = 1:numel(curves)
    c = curves{i};
    M(i,1:numel(c)) = c;
    if numel(c) < L
        M(i,numel(c)+1:L) = c(end); % pad if shorter than common length
    end
end
switch lower(statistic)
    case 'mean'
        y = nanmean_local(M);
    otherwise
        y = nanmedian_local(M);
end
end

function y = nanmean_local(M)
% for each column of M (exact evaluation) collect all runs' best-so-far values
% and calculate their mean
y = zeros(1, size(M,2));
for j = 1:size(M,2)
    col = M(:,j);
    col = col(~isnan(col));
    if isempty(col)
        y(j) = NaN;
    else
        y(j) = mean(col);
    end
end
end

function y = nanmedian_local(M)
y = zeros(1, size(M,2));
for j = 1:size(M,2)
    col = M(:,j);
    col = col(~isnan(col));
    if isempty(col)
        y(j) = NaN;
    else
        y(j) = median(col);
    end
end
end


function c = algorithm_color(alg, fallbackIndex)
% Fixed, high-contrast colors for frequently compared algorithms.
algKey = upper(char(alg));

switch algKey
    case {'TSDDEO','TSDDEO_FIXED'}
        c = [0.00 0.00 0.00];
    case {'TSDDEO_AL_DIST'}
        c = [0.40 0.80 1.00]; % light blue
    case {'TSDDEO_AL_COM'}
        c = [0.93 0.69 0.13]; % yellow
    case 'TSDDEO_AL_DISTCOM'
        c = [0.47 0.67 0.19]; % green
    case 'SA_MPSO_recreated'
        c = [0.00 0.45 0.74]; % blue
    case 'SA_MPSO_AL_COV'
        c = [0.60 0.80 0.60];
    case 'SA_MPSO_AL_A'
        c = [1.00 0.60 0.60];
    case 'SA_MPSO_AL_B'
        c = [0.49 0.18 0.56]; 
    case 'SA_MPSO_AL_COM1'
        c = [0.60 0.40 0.10];
    case 'SA_MPSO_AL_ABOR'
        c = [0.93 0.69 0.13];
    case 'SA_MPSO_AL_AB'
        c = [0.85 0.33 0.10];
    case 'SA_MPSO_AL_BCOV'
        c = [0.47 0.67 0.19];
    case 'SA_MPSO_AL_BCOVor'
        c = [0.30 0.75 0.93];
    case 'SA_MPSO_AL_BCOVADAPT'
        c = [0.64 0.08 0.18];
    case 'SA_MPSO_AL_ABADAPT'
        c = [0.00 0.50 0.50]; 
    otherwise
        palette = [
            0.00 0.45 0.74
            0.60 0.80 0.60
            1.00 0.60 0.60
            0.60 0.20 0.80
            0.60 0.40 0.10
            0.93 0.69 0.13
            0.85 0.33 0.10
            0.47 0.67 0.19
            0.30 0.75 0.93
            0.64 0.08 0.18
            0.00 0.50 0.50
            0.50 0.00 0.50
            0.20 0.20 0.20
            0.75 0.00 0.75
            0.00 0.60 0.20];
        c = palette(mod(fallbackIndex-1, size(palette,1)) + 1, :);
end
end


function labelName = display_algorithm_label(alg)
% Convert long internal algorithm names into shorter plot labels.

labelName = char(alg);
algKey = upper(labelName);

if strcmp(labelName, 'SA_MPSO_recreated')
    labelName = 'SA-MPSO';
elseif strcmp(labelName, 'TSDDEO_fixed')
    labelName = 'TSDDEO-fixed';
elseif strcmp(labelName, 'SA_MPSO_AL_A')
    labelName = 'SA-MPSO-AL-DIST';
elseif strcmp(labelName, 'SA_MPSO_AL_B')
    labelName = 'SA-MPSO-AL-ERR';
elseif strcmp(labelName, 'SA_MPSO_AL_AB')
    labelName = 'SA-MPSO-AL-ERRDIST';
elseif strcmp(labelName, 'SA_MPSO_AL_ABOR')
    labelName = 'SA-MPSO-AL-ERR/DIST';
elseif strcmp(labelName, 'SA_MPSO_AL_COV')
    labelName = 'SA-MPSO-AL-COV';
elseif strcmp(labelName, 'SA_MPSO_AL_COM1')
    labelName = 'SA-MPSO-AL-COM';
elseif strcmp(labelName, 'SA_MPSO_AL_BCOV')
    labelName = 'SA-MPSO-AL-ERRCOV';
elseif strcmp(labelName, 'SA_MPSO_AL_BCOVor')
    labelName = 'SA-MPSO-AL-ERR/COV';
elseif strcmp(algKey, 'SA_MPSO_AL_BCOVADAPT')
    labelName = 'SA-MPSO-AL-ERR/COV-adapt';
elseif strcmp(algKey, 'SA_MPSO_AL_ABADAPT')
    labelName = 'SA-MPSO-AL-ERR/DIST-adapt';
elseif strcmp(algKey, 'SA_MPSO_AL_COVCOM1ADAPT')
    labelName = 'SA-MPSO-AL-COV/COM-adapt';
elseif strcmp(labelName, 'SA_MPSO_AL_COVCOM1')
    labelName = 'SA-MPSO-AL-COVCOM';
elseif strcmp(algKey, 'SA_MPSO_AL_COVCOM1OR')
    labelName = 'SA-MPSO-AL-COV/COM';
elseif strcmp(algKey, 'TSDDEO_AL_DIST')
    labelName = 'TSDDEO-AL-DIST';
elseif strcmp(algKey, 'TSDDEO_AL_COM')
    labelName = 'TSDDEO-AL-COM';
elseif strcmp(algKey, 'TSDDEO_AL_DISTCOM')
    labelName = 'TSDDEO-AL-DISTCOM';
end
end
