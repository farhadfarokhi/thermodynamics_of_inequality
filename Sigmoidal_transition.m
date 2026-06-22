clc
clear

%% Figure setup
fig = figure('Position', [100, 100, 700, 900]);

line_styles = {'-', '--', ':'};
colors = {[0.00, 0.45, 0.74], ...    % blue
          [0.85, 0.33, 0.10], ...    % orange
          [0.50, 0.18, 0.56]};       % purple

E = logspace(-1, 11, 10000);
N = 1000;

%% ========================================================================
%  Panel 1 (TOP) - slope dG/de at the inflection point vs n_1
%  Central finite difference on the dense E grid near the inflection.
%% ========================================================================
ax_top = axes('Position', [0.12 0.72 0.84 0.24]);
hold(ax_top, 'on');

n1_grid_top = logspace(-3, log10(0.99), 200);
Delta_values_top = [0.1, 1, 10];
labels_top = {'$\Delta\!=\!0.1$', '$\Delta\!=\!1.0$', '$\Delta\!=\!10$'};

e_axis = E / N;

for i = 1:length(Delta_values_top)
    Delta = Delta_values_top(i);
    deriv = nan(size(n1_grid_top));
    for k = 1:length(n1_grid_top)
        N1 = round(n1_grid_top(k) * N); N2 = N - N1;
        if N1 < 1 || N1 >= N; continue; end

        E1_star = (sqrt((N - Delta*E).^2 + 4*Delta*N1*E) ...
                   - (N - Delta*E)) / (2*Delta);
        E2_star = E - E1_star;
        G = (N1.*E1_star + N2.*E2_star)./(2*N*E) ...
          + (N2.^2.*E1_star.^2 + N1.^2.*E2_star.^2) ...
            ./ (N2.*E1_star + N1.*E2_star) ./ (N*E);

        half_val = 0.5*(G(end) - G(1)) + G(1);
        idx = find(G >= half_val, 1, 'first');
        if isempty(idx) || idx <= 2 || idx >= length(G)-1; continue; end

        deriv(k) = (G(idx+1) - G(idx-1)) / (e_axis(idx+1) - e_axis(idx-1));
    end
    loglog(ax_top, n1_grid_top, deriv, ...
           'LineStyle', '-', ...
           'Color',     colors{i}, ...
           'LineWidth', 1.4);
end

ax_top.FontSize = 16;
xlabel(ax_top, '$n_1$', 'Interpreter', 'latex', 'FontSize', 20);
ylabel(ax_top, '$(\mathrm{d}G/\mathrm{d}e)_{e=e_{\rm infl}}$', ...
       'Interpreter', 'latex', 'FontSize', 20);
box(ax_top, 'on'); grid(ax_top, 'on');
ax_top.XScale = 'log';
ax_top.YScale = 'log';
ax_top.GridAlpha = 0.4;
ax_top.GridLineStyle = '--';
legend(ax_top, labels_top, 'Interpreter', 'latex', ...
       'Location', 'southwest', 'FontSize', 16);
ylim([1e-5 1e1])

%% ========================================================================
%  Panel 2 (MIDDLE) - G_max vs n_1  (asymptotic high-e limit)
%  Analytic: G_max = 1 - n_1/2,  independent of Delta.
%% ========================================================================
ax_mid = axes('Position', [0.12 0.40 0.84 0.24]);
hold(ax_mid, 'on');

n1_grid_mid = (1:N-1)/N;
G_max_analytic = 1 - n1_grid_mid/2;

Delta_ref = 1;
G_max_num = zeros(1, N-1);
for N1 = 1:N-1
    N2 = N - N1;
    E1_star = (sqrt((N - Delta_ref*E).^2 + 4*Delta_ref*N1*E) ...
               - (N - Delta_ref*E)) / (2*Delta_ref);
    E2_star = E - E1_star;
    G = (N1.*E1_star + N2.*E2_star)./(2*N*E) ...
      + (N2.^2.*E1_star.^2 + N1.^2.*E2_star.^2) ...
        ./ (N2.*E1_star + N1.*E2_star) ./ (N*E);
    G_max_num(N1) = max(G);
end

semilogx(ax_mid, n1_grid_mid, G_max_analytic, '-', ...
         'Color', 'k', 'LineWidth', 1.7);

ax_mid.FontSize = 16;
xlabel(ax_mid, '$n_1$', 'Interpreter', 'latex', 'FontSize', 20);
ylabel(ax_mid, '$G_{\max}$', 'Interpreter', 'latex', 'FontSize', 20);
box(ax_mid, 'on'); grid(ax_mid, 'on');
ax_mid.XScale = 'log';
ax_mid.GridAlpha = 0.4;
ax_mid.GridLineStyle = '--';
xlim(ax_mid, [n1_grid_mid(1) n1_grid_mid(end)]);
ylim(ax_mid, [0.5 1.02]);

%% ========================================================================
%  Panel 3 (BOTTOM) - inflection e_infl vs Delta, for three n_1 values
%  Numerical inflection = where G reaches 50% of its asymptotic rise.
%% ========================================================================
ax_bot = axes('Position', [0.12 0.08 0.84 0.24]);
hold(ax_bot, 'on');

Delta_range = logspace(-2, 2, 100);
n1_values_bot = [3, 30, 300]/N;
labels_bot = {'$n_1\!=\!0.3\%$', '$n_1\!=\!3.0\%$', '$n_1\!=\!30\%$'};

for i = 1:3
    N1 = round(n1_values_bot(i) * N); N2 = N - N1;
    tau = nan(size(Delta_range));
    for j = 1:length(Delta_range)
        Delta = Delta_range(j);
        E1_star = (sqrt((N - Delta*E).^2 + 4*Delta*N1*E) ...
                   - (N - Delta*E)) / (2*Delta);
        E2_star = E - E1_star;
        G = (N1.*E1_star + N2.*E2_star)./(2*N*E) ...
          + (N2.^2.*E1_star.^2 + N1.^2.*E2_star.^2) ...
            ./ (N2.*E1_star + N1.*E2_star) ./ (N*E);

        half_val = 0.5*(G(end) - G(1)) + G(1);
        idx = find(G >= half_val, 1, 'first');
        if ~isempty(idx); tau(j) = E(idx)/N; end
    end
    semilogx(ax_bot, Delta_range, tau, ...
             'LineStyle', line_styles{i}, ...
             'Color',     'k', ...
             'LineWidth', 1.4);
end

ax_bot.FontSize = 16;
xlabel(ax_bot, '$\Delta$', 'Interpreter', 'latex', 'FontSize', 20);
ylabel(ax_bot, '$e_{\rm infl}$', 'Interpreter', 'latex', 'FontSize', 20);
box(ax_bot, 'on'); grid(ax_bot, 'on');
ax_bot.XScale = 'log';
% ax_bot.YScale = 'log';
ax_bot.GridAlpha = 0.4;
ax_bot.GridLineStyle = '--';
legend(ax_bot, labels_bot, 'Interpreter', 'latex', ...
       'Location', 'northeast', 'FontSize', 16);

%% ---- SAVE --------------------------------------------------------------
if ~exist('figures', 'dir'); mkdir('figures'); end
exportgraphics(gcf, 'figures/phase_transition.pdf', 'ContentType', 'vector');
fprintf('Saved phase_transition.pdf\n');