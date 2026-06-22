clear; clc; close all;

% Create output folder if it doesn't exist
if ~exist('figures', 'dir'), mkdir('figures'); end

%% ========================================================================
%  Load and validate data
%  ========================================================================

fprintf('Loading data...\n');
opts = detectImportOptions('data/oecd_merged.csv', 'TextType', 'string');
T = readtable('data/oecd_merged.csv', opts);

% Validate required columns
required_cols = {'CountryCode','CountryName','Year','GDP_PPP', ...
                                            'Gini','TaxRate','GradShare'};
for c = required_cols
    if ~ismember(c{1}, T.Properties.VariableNames)
        error('Missing required column: %s', c{1});
    end
end

% Convert string columns to numeric where needed
numeric_cols = {'GDP_PPP','Gini','TaxRate','GradShare'};
for c = numeric_cols
    if iscell(T.(c{1})) || isstring(T.(c{1}))
        T.(c{1}) = str2double(T.(c{1}));
    end
end

% Drop rows with any missing key values
valid = all(~isnan(T{:, numeric_cols}), 2);
n_dropped = sum(~valid);
T = T(valid, :);
fprintf(['Loaded %d country-year observations' ...
    ' (%d dropped for missing data).\n'], height(T), n_dropped);
fprintf('Countries: %d | Years: %d–%d\n', ...
    numel(unique(T.CountryCode)), min(T.Year), max(T.Year));

% ---- Normalise units ----------------------------------------------------
% Gini: ensure 0-1 scale
if max(T.Gini) > 1
    fprintf(['Gini values > 1 detected; assuming ' ...
        'percentage; dividing by 100.']);
    T.Gini = T.Gini / 100;
end

% GradShare: ensure 0-1 scale (not percent)
if max(T.GradShare) > 1
    fprintf(['GradShare values > 1 detected; assuming ' ...
        'percentage; dividing by 100.']);
    T.GradShare = T.GradShare / 100;
end

% TaxRate: keep as percentage (0-100) 

%% ========================================================================
%  Setting plotting parameters
%  ========================================================================

% Common figure size and font
fig_sz   = [120 120 680 490];

%% ========================================================================
%  Gini vs GDP, faceted by n1 quartile
%  ========================================================================

fprintf('Generating Figure: Gini vs GDP faceted by n1 quartile...\n');

q_edges  = quantile(T.GradShare, [0 0.25 0.5 0.75 1.0]);
q_labels = { ...
    sprintf('$n_1 \\in [%.3f, %.3f]$', q_edges(1), q_edges(2)), ...
    sprintf('$n_1 \\in [%.3f, %.3f]$', q_edges(2), q_edges(3)), ...
    sprintf('$n_1 \\in [%.3f, %.3f]$', q_edges(3), q_edges(4)), ...
    sprintf('$n_1 \\in [%.3f, %.3f]$', q_edges(4), q_edges(5))  };
qcols = [0.22 0.47 0.69;
         0.30 0.68 0.29;
         0.89 0.10 0.11;
         0.60 0.31 0.64];

f4 = figure('Name','Gini GDP quartile','Position',[120 120 900 680]);

for q = 1:4
    if q < 4
        idx = T.GradShare >= q_edges(q) & T.GradShare < q_edges(q+1);
    else
        idx = T.GradShare >= q_edges(q) & T.GradShare <= q_edges(q+1);
    end

    ax = subplot(2,2,q);
    hold on;

    % Gini is multiplied by two due to rule of tumb: Gini for wealth 
    % twice Gini for income
    scatter(T.GDP_PPP(idx)/1e4, 2*T.Gini(idx), 28, qcols(q,:),'k', ...
        'filled', 'MarkerFaceAlpha', 0.65);

    n_obs = sum(idx);

    [rho_q, p_q] = corr(T.GDP_PPP(idx), 2*T.Gini(idx), 'Type','Spearman', ...
                                                     'rows','complete');
    text(0.98, 0.95, sprintf(['Spearman correlation = %.2f,\n  ' ...
        'p-value = %.3f,\nn = %d obs'], rho_q, p_q, n_obs), ...
       'Units','normalized','FontSize', 16, 'VerticalAlignment','top', ...
       'HorizontalAlignment','right', ...
       'BackgroundColor',[1 1 1 0.7],'EdgeColor',[0.8 0.8 0.8]);

    ylim([0.4 1.0])
    xlabel('GDP per capita (×10^4 USD)', 'FontSize', 16);
    ylabel('Gini', 'FontSize', 16);
    title(q_labels{q}, 'FontSize', 16,'Interpreter', 'latex');
    box on; grid on;
    set(ax, 'FontSize', 16 );
end

exportgraphics(f4, 'figures/gini_gdp_by_quartile.pdf', ...
                   'ContentType','vector');

%% ========================================================================
%  Summary table — per-country statistics
%  ========================================================================

fprintf('\n--- Per-country summary ---\n');
fprintf('%-6s %-22s %6s %8s %8s %8s\n', ...
    'ISO3','Country','N_obs','GDP_med','Gini_max','n1_med');
fprintf('%s\n', repmat('-',1,60));

countries_list = unique(T.CountryCode);
for k = 1:numel(countries_list)
    idx = T.CountryCode == countries_list(k);
    fprintf('%-6s %-22s %6d %8.0f %8.3f %8.4f\n', ...
        countries_list(k), ...
        T.CountryName(find(idx,1)), ...
        sum(idx), ...
        median(T.GDP_PPP(idx)), ...
        max(T.Gini(idx)), ...
        median(T.GradShare(idx)));
end

fprintf('\nAll figures saved to figures/\n');