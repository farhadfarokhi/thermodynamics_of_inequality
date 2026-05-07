clear; clc; close all;

%% ---- FIXED PARAMETERS --------------------------------------------------
N         = 1000;
n1_vec    = [0.003, 0.03, 0.30];
n1_titles = {'$n_1 = 0.3\%$', '$n_1 = 3\%$', '$n_1 = 30\%$'};

Bh  = 0.05;
Bl  = 0.05;
Ahh = 0.5;
All = 0.5;

e_vec = logspace(-5, 2, 300);

%% ---- PARAMETER SETS ----------------------------------------------------
paramSets = [
    0.5,  0.1,  1.0;
    1.0,  0.1,  1.1;
    0.5,  0.4,  2.0;
    0.5,  0.4,  0.6;
];

% Three-line labels for right-side boxes
rowLabels3 = {
    {'$\lambda_{\mathrm{hi}} = 0.5$',  ...
     '$\lambda_{\mathrm{lo}} = 0.1$',  ...
     '$\lambda_{\mathrm{gov}} = 1.0$'};
    {'$\lambda_{\mathrm{hi}} = 1.0$',  ...
     '$\lambda_{\mathrm{lo}} = 0.1$',  ...
     '$\lambda_{\mathrm{gov}} = 1.1$'};
    {'$\lambda_{\mathrm{hi}} = 0.5$',  ...
     '$\lambda_{\mathrm{lo}} = 0.4$',  ...
     '$\lambda_{\mathrm{gov}} = 2.0$'};
    {'$\lambda_{\mathrm{hi}} = 0.5$',  ...
     '$\lambda_{\mathrm{lo}} = 0.4$',  ...
     '$\lambda_{\mathrm{gov}} = 0.6$'};
};

LW_h = 2.0;
LW_l = 1.0;

%% ---- HELPER ------------------------------------------------------------
sat = @(x) min(max(x, 0), 1);

%% ---- FIGURE ------------------------------------------------------------
figure('Units','centimeters','Position',[2 2 25 26]);
tl = tiledlayout(4, 3, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.88 1];

xlabel(tl, '$e = E/N$', 'Interpreter','latex','FontSize',14);
ylabel(tl, 'Tax rate' , 'Interpreter','latex','FontSize',14);

hh_leg   = [];
ax_first = [];
ax_right = gobjects(4,1);   % rightmost axes per row

for p = 1:size(paramSets,1)
    lh   = paramSets(p,1);
    ll   = paramSets(p,2);
    lgov = paramSets(p,3);

    for ni = 1:numel(n1_vec)
        n1 = n1_vec(ni);
        N1 = max(round(n1 * N), 2);
        N2 = N - N1;

        %-- Solve ---------------------------------------------------------
        alpha_h_vec = nan(size(e_vec));
        alpha_l_vec = nan(size(e_vec));
        x0 = [0.5, 0.0, 0.0];

        for k = 1:numel(e_vec)
            E = e_vec(k) * N;
            F = @(x) residual(x, E, N1, N2, lh, ll, lgov, ...
                              Bh, Bl, Ahh, All, sat);
            opts = optimoptions('fsolve','Display','off', ...
                                'TolFun',1e-20,'TolX',1e-20, ...
                                'MaxIterations',1e4);
            [xsol, ~, exitflag] = fsolve(F, x0, opts);
            if exitflag > 0
                s  = xsol(1);
                E1 = s * E;
                E2 = (1-s) * E;
                alpha_h_vec(k) = sat((1/Ahh)*((1-lh/lgov)*E1 - Bh));
                alpha_l_vec(k) = sat((1/All) *((1-ll/lgov)*E2 - Bl));
                x0 = xsol;
            end
        end

        %-- Plot ----------------------------------------------------------
        ax = nexttile;
        hold(ax,'on'); box(ax,'on'); grid(ax,'on');

        indices = find(~isnan(alpha_h_vec));
        hh = plot(ax, e_vec(indices), alpha_h_vec(indices), '-', ...
                      'Color','k', 'LineWidth', LW_h);
        indices = find(~isnan(alpha_l_vec));
        hl = plot(ax, e_vec(indices), alpha_l_vec(indices), '--', ...
                      'Color','k', 'LineWidth', LW_l);

        set(ax,'XScale','log','TickLabelInterpreter', ...
               'latex','FontSize',14);
        ylim(ax, [-0.1 1.1]);

        % n1 column titles on top row only
        if p == 1
            title(ax, n1_titles{ni}, 'Interpreter','latex', ...
                'FontSize',14);
        end

        % Capture rightmost axes for each row
        if ni == 3
            ax_right(p) = ax;
        end

        % Capture legend handles from very first panel
        if p == 1 && ni == 1
            hh_leg   = [hh, hl];
            ax_first = ax;
        end

        hold(ax,'off');
    end
end

%% ---- LEGEND OUTSIDE ON TOP IN ONE ROW ----------------------------------
lg = legend(ax_first, hh_leg, ...
            {'$\alpha_{\mathrm{hi}}^*$ (elite rate)', ...
             '$\alpha_{\mathrm{lo}}^*$ (non-elite rate)'}, ...
            'Interpreter','latex','FontSize',14,'Box','on', ...
            'Orientation','horizontal','NumColumns',2);
lg.Layout.Tile = 'north';

%% ---- RIGHT-HAND ROW LABELS ---------------------------------------------
drawnow;

tbLeft  = 0.86;    % just right of the narrowed tile grid
tbWidth = 0.10;    % fills to right edge of figure

% Evenly divide vertical space across 4 rows (accounting for top legend)
plotBottom = 0.04;
plotTop    = 0.95;
rowHeight  = (plotTop - plotBottom) / 4;

for p = 1:4
    tbBottom = plotTop - p * rowHeight;
    annotation('textbox', [tbLeft tbBottom tbWidth rowHeight], ...
               'String',             rowLabels3{p}, ...
               'Interpreter',        'latex', ...
               'FontSize',           14, ...
               'EdgeColor',          'none', ...
               'BackgroundColor',    'none', ...
               'VerticalAlignment',  'middle', ...
               'HorizontalAlignment','left', ...
               'FitBoxToText',       'off');
end

%% ---- SAVE --------------------------------------------------------------
exportgraphics(gcf,'figures/taxrates_vs_e.pdf','ContentType','vector');
fprintf('Saved taxrates_vs_e.pdf.png\n');

%% ---- RESIDUAL ----------------------------------------------------------
function F = residual(x, E, N1, N2, lh, ll, lgov, Bh, Bl, Ahh, All, sat)
    s  = x(1);
    ah = x(2);
    al = x(3);
    E1 = max(s*E,     1e-10);
    E2 = max((1-s)*E, 1e-10);
    b1 = lh*(1-ah) + lgov*ah + (N1-1)/E1;
    b2 = ll*(1-al) + lgov*al + (N2-1)/E2;
    ah_star = sat((1/Ahh)*((1-lh/lgov)*E1 - Bh));
    al_star = sat((1/All) *((1-ll/lgov)*E2 - Bl));
    F(1) = b1 - b2;
    F(2) = ah - ah_star;
    F(3) = al - al_star;
end