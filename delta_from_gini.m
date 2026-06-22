% DELTA_FROM_GINI  Recover the rationality gap Delta for each OECD country
% by inverting the closed-form Gini, Eq. (22)
%
%   G(z;n1) = (n1 z + n2 (1-z))/2 + (n2^2 z^2 + n1^2 (1-z)^2)/(n2 z + n1 (1-z))
%   xi(z)   = (z - n1) / (z (1-z)),        z = E1*/E in (n1, 1)
%
% G is strictly monotone from Gmin = 1/2 (z=n1) to Gmax = 1 - n1/2 (z->1).
% Given (G_obs, n1, e):  invert G -> z -> xi, then  Delta = xi / e.
%
% Outputs:  figures/delta_estimates.csv  and  figures/delta_bar.pdf

clear; clc;
if ~exist('figures','dir'), mkdir('figures'); end

%% ---- Load (mirrors gini_vs_postgraduate.m) -----------------------------
opts = detectImportOptions('data/oecd_merged.csv', 'TextType', 'string');
T = readtable('data/oecd_merged.csv', opts);
numeric_cols = {'GDP_PPP','Gini','TaxRate','GradShare'};
for c = numeric_cols
    if iscell(T.(c{1})) || isstring(T.(c{1})), T.(c{1}) = str2double(T.(c{1})); end
end
T = T(all(~isnan(T{:, numeric_cols}), 2), :);
if max(T.Gini) > 1,      T.Gini = T.Gini / 100;      end
if max(T.GradShare) > 1, T.GradShare = T.GradShare / 100; end

countries = unique(T.CountryCode);
nc = numel(countries);

%% ---- Per-country inversion ---------------------------------------------
rows = {};
for k = 1:nc
    idx   = T.CountryCode == countries(k);
    cname = T.CountryName(find(idx,1));
    n1    = median(T.GradShare(idx));
    Gmax  = 1 - n1/2;

    % per-year inversion
    g = 2*T.Gini(idx);  e = T.GDP_PPP(idx);
    Dyr = nan(numel(g),1);
    for j = 1:numel(g)
        [Dyr(j), ~, ok] = delta_one(g(j), n1, e(j));
        if ~ok, Dyr(j) = NaN; end
    end
    dvals  = Dyr(~isnan(Dyr));
    nfeasB = numel(dvals);
    if nfeasB >= 1
        DeltaB = median(dvals);
        if nfeasB >= 2
            qq = quantile(dvals,[0.25 0.75]); 
        else 
            qq = [DeltaB DeltaB]; 
        end
        Q1 = qq(1); Q3 = qq(2);
    else
        DeltaB = NaN; Q1 = NaN; Q3 = NaN;
    end

    rows(end+1,:) = {char(countries(k)), char(cname), n1, Gmax, ...
                     nfeasB, numel(g), DeltaB, Q1, Q3}; %#ok<AGROW>
end

R = cell2table(rows, 'VariableNames', ...
    {'ISO3','Country','n1','Gmax', ...
     'nfeas','nobs','DeltaB_med','DeltaB_Q1','DeltaB_Q3'});
R = sortrows(R, 'DeltaB_med');

%% ---- Bar chart: one bar per country ------------------------------------

keep = R.nfeas > 0 & ~isnan(R.DeltaB_med);
Rp = sortrows(R(keep,:), 'DeltaB_med');
nb = height(Rp);
 
f = figure('Name','Delta per country','Position',[120 120 1840 340]);
hold on;
bar(1:nb, Rp.DeltaB_med, 0.72, 'FaceColor',[0.65 0.65 0.65], ...
    'EdgeColor','k', 'LineWidth',0.5);
  
set(gca, 'XTick',1:nb, 'XTickLabel',Rp.Country, 'XTickLabelRotation',90, ...
         'FontSize',11, 'TickLabelInterpreter','none','FontSize',16);
ylabel('rationality gap', 'FontSize',16);
xlim([0.5, nb+0.5]);
ylim([1e-6 1e-2])
set(gca,'YScale','log');
box on; grid on;
exportgraphics(f, 'figures/delta_bar.pdf', 'ContentType','vector');
 
fprintf('Wrote figures/delta_estimates.csv and figures/delta_bar.pdf\n');
 
%% ======================================================================
function [Delta, xi, feasible] = delta_one(Gobs, n1, e)
    Gmax = 1 - n1/2;
    feasible = (Gobs > 0.5) && (Gobs < Gmax);
    if ~feasible, Delta = NaN; xi = NaN; return; end
    z  = fzero(@(z) Gz(z,n1) - Gobs, [n1 + 1e-12, 1 - 1e-12]);
    xi = (z - n1) ./ (z .* (1 - z));
    Delta = xi / e;
end
 
function G = Gz(z, n1)
    n2 = 1 - n1;
    G = (n1.*z + n2.*(1-z))/2 + ...
        (n2.^2.*z.^2 + n1.^2.*(1-z).^2) ./ (n2.*z + n1.*(1-z));
end
 