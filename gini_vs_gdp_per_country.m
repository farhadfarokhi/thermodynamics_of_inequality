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
%  Within-country Gini vs GDP (with Spearman correlation annotations)
%  - Annotation placed below the country title via subtitle().
%  - `axis padded` adds a small margin so points don't sit on axis edges.
%  ========================================================================
 
fprintf('Generating Figure: Within-country Gini vs GDP...\n');
 
countries_fig7 = ["CHE","DNK","GBR","DEU","IRL","LTU","EST","GRC","SWE"];
labels_fig7    = ["Switzerland","Denmark","United Kingdom","Germany", ...
                  "Ireland","Lithuania","Estonia","Greece","Sweden"];
 
f7 = figure('Name','Within-country','Position',[120 120 900 760]);
 
for k = 1:numel(countries_fig7)
    idx = T.CountryCode == countries_fig7(k);
 
    subplot(3, 3, k);
    hold on;
 
    % Gini is multiplied by two due to rule of tumb: Gini for wealth 
    % twice Gini for income
    scatter(T.GDP_PPP(idx)/1e4, 2*T.Gini(idx), 28, 'k', ...
        'filled', 'MarkerFaceAlpha', 1);
 
    spearman_str = '';
    if sum(idx) > 2
        [rho_c, p_c] = corr(T.GDP_PPP(idx), 2*T.Gini(idx), ...
                            'Type','Spearman', 'rows','complete');
        spearman_str = sprintf('Spearman corr. = %.2f, p-value = %.3f', ...
                               rho_c, p_c);
    end

    axis padded                           % small margin around data

    xlabel('GDP per capita (\times10^4 USD)', 'FontSize', 16);
    ylabel('Gini', 'FontSize', 16);
    title(labels_fig7(k), 'FontSize', 16);
    if ~isempty(spearman_str)
        subtitle(spearman_str, 'FontSize', 12);
    end
    box on; grid on;
    ax = gca;
    ax.XAxis.FontSize = 14;  % Change X-axis tick numbers
    ax.YAxis.FontSize = 14;
end
 
exportgraphics(f7, 'figures/within_country.pdf', 'ContentType','vector');