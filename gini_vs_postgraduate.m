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
%  Empirical Gmax vs n1
%  ========================================================================

fprintf('Generating Figure: G_max vs n1 (theory test)...\n');

countries = unique(T.CountryCode);
nc = numel(countries);
Gmax_emp = NaN(nc,1);
n1_emp   = NaN(nc,1);
cname    = strings(nc,1);

for k = 1:nc
    idx = T.CountryCode == countries(k);
    Gmax_emp(k) = max(T.Gini(idx));
    n1_emp(k)   = median(T.GradShare(idx));
    cname(k)    = T.CountryName(find(idx,1));
end

valid_c = ~isnan(Gmax_emp) & ~isnan(n1_emp);
Gmax_emp = Gmax_emp(valid_c);
n1_emp   = n1_emp(valid_c);
cname    = cname(valid_c);

f3 = figure('Name','Gmax vs n1','Position', fig_sz);
hold on;

% Gmax_emp is multiplied by two due to rule of tumb: Gini for wealth 
% twice Gini for income
h_emp = scatter(n1_emp, 2*Gmax_emp, 55, 'k', 'filled', ...
    'MarkerFaceAlpha', 0.8, 'DisplayName', 'OECD countries (median n_1)');

annotate_spearman(n1_emp, 2*Gmax_emp);

box on; grid on; grid minor;

xlabel('Postgraduate fraction', 'FontSize', 16);
ylabel('Gini'       , 'FontSize', 16);
xlim([0, 0.05]);  ylim([0.4, 1.0]);
box on; grid on;
set(gca, 'FontSize', 16);

exportgraphics(f3, 'figures/Gmax_vs_n1.pdf', 'ContentType','vector');

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

%% ========================================================================
%  Local functions
%  ========================================================================

function annotate_spearman(x, y, pos)
    % pos: 'tl' top-left (default), 'tr' top-right
    [rho, pval] = corr(x(:), y(:), 'Type', 'Spearman', 'Rows', 'complete');
    if nargin < 3 || strcmp(pos,'tl')
        ax_pos = [0.04 0.93];
        va = 'top';
    else
        ax_pos = [0.96 0.93];
        va = 'top';
    end
    text(ax_pos(1), ax_pos(2), ...
         sprintf(['Spearman correlation = %.2f, ' ...
         ' p-value = %.3f'], rho, pval), ...
         'Units','normalized','FontSize', 16, 'VerticalAlignment', va, ...
         'HorizontalAlignment', 'left', ...
         'BackgroundColor', [1 1 1 0.7], 'EdgeColor', [0.8 0.8 0.8]);
end
