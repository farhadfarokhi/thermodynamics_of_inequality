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
fprintf('Countries: %d | Years: %d-%d\n', ...
    numel(unique(T.CountryCode)), min(T.Year), max(T.Year));

% ---- Normalise units ----------------------------------------------------
if max(T.Gini) > 1
    fprintf(['Gini values > 1 detected; assuming ' ...
        'percentage; dividing by 100.\n']);
    T.Gini = T.Gini / 100;
end
if max(T.GradShare) > 1
    fprintf(['GradShare values > 1 detected; assuming ' ...
        'percentage; dividing by 100.\n']);
    T.GradShare = T.GradShare / 100;
end

%% ========================================================================
%  Setting plotting parameters
%  ========================================================================

% Common figure size
fig_sz = [120 120 680 490];

%% ========================================================================
%  Gini vs GDP per capita - all countries pooled
%  ========================================================================

fprintf('Generating Figure: Gini vs GDP ...\n');

f1 = figure('Name','Gini vs GDP','Position', fig_sz);
hold on;

% Gini is multiplied by two due to rule of tumb: Gini for wealth twice Gini
% for income
scatter(T.GDP_PPP/1e4, 2*T.Gini, 32, 'k', 'filled', ...
                           'MarkerFaceAlpha', 1, 'MarkerEdgeColor','none');

xlim([0 16]);
ylim([0.4 1.]);

xlabel('GDP per capita (\times10^4 USD)', 'FontSize', 16);
ylabel('Gini', 'FontSize', 16);
box on; grid on; grid minor;
set(gca, 'FontSize', 16);

exportgraphics(f1, 'figures/gini_vs_gdp.pdf', ...
                   'ContentType','vector');

fprintf('\nFigure saved to figures/gini_vs_gdp.pdf\n');