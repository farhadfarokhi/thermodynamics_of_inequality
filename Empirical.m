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

% Colour map: GradShare encoded as greyscale
cmap = flipud(gray(256));
gs_lo = quantile(T.GradShare, 0.02);
gs_hi = quantile(T.GradShare, 0.98);
gs_norm = (T.GradShare - gs_lo) / (gs_hi - gs_lo);
gs_norm = max(0, min(1, gs_norm));
cidx = max(1, round(gs_norm * 255) + 1);
pt_colors = cmap(cidx, :);

% Common figure size and font
fig_sz   = [120 120 680 490];

%% ========================================================================
%  Tax rate vs GDP, n1 is depicted via greyscale
%  ========================================================================

fprintf('Generating Figure: Tax rate vs GDP (greyscale n1)...\n');

f2 = figure('Name','Tax vs GDP','Position', fig_sz);
hold on;

scatter(T.GDP_PPP/1e4, T.TaxRate, 32, pt_colors, 'filled', ...
                           'MarkerFaceAlpha', 1, 'MarkerEdgeColor','none');

gdp_norm = T.GDP_PPP / 1e4;
X_t = [ones(height(T),1), gdp_norm];
b_t = X_t \ T.TaxRate;
gdp_rng = linspace(min(gdp_norm), max(gdp_norm), 300);
plot(gdp_rng, b_t(1) + b_t(2)*gdp_rng, 'k-', 'LineWidth', 1.8);

xlim([0 16])
ylim([0 70])

annotate_spearman(T.GDP_PPP, T.TaxRate);
add_colorbar(gs_lo, gs_hi);

xlabel('GDP per capita (×10^4 USD)', 'FontSize', 16);
ylabel('Tax rate (%)', 'FontSize', 16);
box on; grid on; grid minor;
set(gca, 'FontSize', 16);

exportgraphics(f2, 'figures/tax_vs_gdp_n1color.pdf', ...
                   'ContentType','vector');

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

h_emp = scatter(n1_emp, Gmax_emp, 55, 'k', 'filled', ...
    'MarkerFaceAlpha', 0.8, 'DisplayName', 'OECD countries (median n_1)');

X_g = [ones(numel(n1_emp),1), n1_emp];
b_g = X_g \ Gmax_emp;
n1_rng = linspace(min(n1_emp), max(n1_emp), 200);
h_fit = plot(n1_rng, b_g(1) + b_g(2)*n1_rng, 'k-', 'LineWidth', 1.3, ...
        'DisplayName', sprintf('OLS fit:  G_{max} = %.2f + %.2f n_1', ...
        b_g(1), b_g(2)));

annotate_spearman(n1_emp, Gmax_emp);

box on; grid on; grid minor;

xlabel('Fractional size of MSc and PhD graduates', 'FontSize', 16);
ylabel('Maximum observed Gini coefficient'       , 'FontSize', 16);
xlim([0, 0.05]);  ylim([0.1, 0.6]);
box on; grid on;
set(gca, 'FontSize', 16);

exportgraphics(f3, 'figures/Gmax_vs_n1.pdf', 'ContentType','vector');

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

    scatter(T.GDP_PPP(idx)/1e4, T.Gini(idx), 28, qcols(q,:),'k', ...
        'filled', 'MarkerFaceAlpha', 0.65);

    n_obs = sum(idx);
    if n_obs > 5
        X_q = [ones(n_obs,1), T.GDP_PPP(idx)];
        b_q = X_q \ T.Gini(idx);
        gdp_q = linspace(min(T.GDP_PPP(idx)), max(T.GDP_PPP(idx)), 200);
        plot(gdp_q/1e4, b_q(1) + b_q(2)*(gdp_q), '-', ...
            'Color', 'k', 'LineWidth', 1.6);
        ylim([0.2 0.5])
        xlim([0 15])
    end

    [rho_q, p_q] = corr(T.GDP_PPP(idx), T.Gini(idx), 'Type','Spearman', ...
                                                     'rows','complete');
    text(0.98, 0.95, sprintf(['Spearman correlation = %.2f,\n  ' ...
        'p-value = %.3f,\nn = %d obs'], rho_q, p_q, n_obs), ...
       'Units','normalized','FontSize', 16, 'VerticalAlignment','top', ...
       'HorizontalAlignment','right', ...
       'BackgroundColor',[1 1 1 0.7],'EdgeColor',[0.8 0.8 0.8]);

    xlabel('GDP per capita (×10^4 USD)', 'FontSize', 16);
    ylabel('Gini', 'FontSize', 16);
    title(q_labels{q}, 'FontSize', 16,'Interpreter', 'latex');
    box on; grid on;
    set(ax, 'FontSize', 16 );
end

exportgraphics(f4, 'figures/gini_gdp_by_quartile.pdf', ...
                   'ContentType','vector');

%% ========================================================================
%  Within-country Gini vs GDP
%  ========================================================================
 
fprintf('Generating Figure: Within-country Gini vs GDP...\n');
 
countries_fig7 = ["CHE","DNK","GBR","DEU","IRL","LTU","EST","GRC","SWE"];
labels_fig7    = ["Switzerland","Denmark","United Kingdom","Germany", ...
                  "Ireland","Lithuania","Estonia","Greece","Sweden"];
 
f7 = figure('Name','Within-country','Position',[120 120 900 680]);
 
for k = 1:numel(countries_fig7)
    idx = T.CountryCode == countries_fig7(k);
 
    subplot(3, 3, k);
    hold on;
 
    scatter(T.GDP_PPP(idx)/1e4, T.Gini(idx), 28, 'k', ...
        'filled', 'MarkerFaceAlpha', 1);
 
    if sum(idx) > 2
        p = polyfit(T.GDP_PPP(idx)/1e4, T.Gini(idx), 1);
        x_fit = linspace(min(T.GDP_PPP(idx)/1e4), ...
                         max(T.GDP_PPP(idx)/1e4), 100);
        plot(x_fit, polyval(p, x_fit), 'k-', 'LineWidth', 1.4);
    end

    xlabel('GDP per capita (×10^4 USD)', 'FontSize', 16);
    ylabel('Gini',      'FontSize', 16);
    title(labels_fig7(k), 'FontSize', 16);
    box on; grid on;
    set(gca, 'FontSize', 16);
end
 
exportgraphics(f7, 'figures/within_country.pdf', 'ContentType','vector');

%% ========================================================================
%  Tax rate vs GDP, faceted by n1 quartile
%  ========================================================================

fprintf('Generating Figure: Tax vs GDP faceted by n1 quartile...\n');

f6 = figure('Name','Tax GDP quartile','Position',[120 120 900 680]);

for q = 1:4
    if q < 4
        idx = T.GradShare >= q_edges(q) & T.GradShare < q_edges(q+1);
    else
        idx = T.GradShare >= q_edges(q) & T.GradShare <= q_edges(q+1);
    end

    ax = subplot(2,2,q);
    hold on;

    scatter(T.GDP_PPP(idx)/1e4, T.TaxRate(idx), 28, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.65);

    n_obs = sum(idx);
    if n_obs > 5
        X_q  = [ones(n_obs,1), T.GDP_PPP(idx)/1e4];
        b_q  = X_q \ T.TaxRate(idx);
        gv   = linspace(min(T.GDP_PPP(idx)), max(T.GDP_PPP(idx)), 200);
        plot(gv/1e4, b_q(1) + b_q(2)*gv/1e4, '-', ...
            'Color', 'k', 'LineWidth', 1.6);
        ylim([0. 80])
        xlim([0 15])
    end

    [rho_q, p_q] = corr(T.GDP_PPP(idx),T.TaxRate(idx),'Type','Spearman',...
                                                      'rows','complete');
    text(0.98, 0.95, sprintf(['Spearman correlation = %.2f,\n  ' ...
        'p-value = %.3f,\nn = %d obs'], rho_q, p_q, n_obs), ...
       'Units','normalized','FontSize', 16, 'VerticalAlignment','top', ...
       'HorizontalAlignment','right', ...
       'BackgroundColor',[1 1 1 0.7],'EdgeColor',[0.8 0.8 0.8]);

    xlabel('GDP per capita (×10^4 USD)', 'FontSize', 16);
    ylabel('Tax rate (%)', 'FontSize', 16);
    title(q_labels{q}, 'FontSize', 16,'Interpreter', 'latex');
    box on; grid on;
    set(ax, 'FontSize', 16 );
end

exportgraphics(f6, 'figures/tax_gdp_by_quartile.pdf', ...
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

%% ========================================================================
%  Local functions
%  ========================================================================

function add_colorbar(gs_lo, gs_hi)
    cb = colorbar('eastoutside');
    cb.Label.String = 'Fractional size of MSc and PhD graduates';
    cb.Label.FontSize = 16;
    colormap(flipud(gray));
    clim([gs_lo, gs_hi]);
    cb.Ticks = linspace(gs_lo, gs_hi, 5);
    cb.TickLabels = arrayfun(@(x) sprintf('%.3f', x), cb.Ticks, ...
                    'UniformOutput', false);
end

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
