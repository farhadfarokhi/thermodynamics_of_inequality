clc
clear

%%

% Parameters
param1_values = [0.1,1,10];          % Delta values (rationality gap)
param2_values = [3,30,300];          % N1 values (elite size; n1 = N1/N)

line_styles = {'-', '--', ':'};
markers        = {'*', 's', 'o'};       % *, diamond, circle
marker_spacing = 30;                    % plot a marker every N points

% --- Colour palette --------------------------------------------------
% Default: colour follows Delta (one colour per rationality-gap row).
%   colour 1 -> Delta = 0.1   (blue)
%   colour 2 -> Delta = 1.0   (orange)
%   colour 3 -> Delta = 10    (purple)
% To colour by n1 instead, swap the two 'Color' references below:
%   main loop  : colors{j}  ->  colors{i}
%   legend loop: colors{i}  ->  colors{j}
colors = {[0.00, 0.45, 0.74], ...    % blue
          [0.85, 0.33, 0.10], ...    % orange
          [0.50, 0.18, 0.56]};       % purple

param1_labels = {'$\Delta\!=\!0.1$', '$\Delta\!=\!1.0$', '$\Delta\!=\!10$'};
param2_labels = {'$n_1\!=\!0.3\%\quad$', '$n_1\!=\!3.0\%\quad$', '$n_1\!=\!30\%\quad$'};

E = logspace(-1,11,1000);
N=1000;

%% --- Main plot ---
fig = figure;
ax_main = axes('Position', [0.09 0.11 0.88 0.88]);
hold(ax_main, 'on');

for i = 1:3                              % i indexes n1 (marker + colour)
    for j = 1:3                          % j indexes Delta (line style)
    
        Delta=param1_values(j);
        N1=param2_values(i);
        N2=N-N1;

        E1_star=(sqrt((N-Delta*E).^2+4*Delta*N1*E)-(N-Delta*E))./(2*Delta);
        E2_star=E-E1_star;
            
        G=(N1.*E1_star+N2.*E2_star)./(2*N*E)+(N2.^2*E1_star.^2+N1.^2*E2_star.^2)./(N2.*E1_star+N1.*E2_star)./(N*E);

        semilogx(ax_main, E/N, G, ...
            'LineStyle',        line_styles{j}, ...
            'Marker',           markers{i}, ...
            'MarkerIndices',    1:marker_spacing:numel(E), ...
            'Color',            colors{j}, ...     % <-- colour by Delta
            'LineWidth',        1.2, ...
            'MarkerSize',       7);
    end
end

set(ax_main, 'XScale', 'log');

ax_main.FontSize = 14;
xlabel(ax_main, '$e$', 'Interpreter', 'latex', 'FontSize', 19);
ylabel(ax_main, '$G$', 'Interpreter', 'latex', 'FontSize', 19);
box(ax_main, 'on');
grid(ax_main, 'on');
ax_main.Layer   = 'top';
ax_main.XScale  = 'log';
ax_main.GridAlpha      = 0.4;
ax_main.GridLineStyle  = '--';
ylim(ax_main, [.4, 1.1]);

%% --- Compact inset legend ---
ax_leg = axes('Position', [0.53 0.13 0.42 0.30]);
hold(ax_leg, 'on');
axis(ax_leg, 'off');

n1 = numel(param1_values);
n2 = numel(param2_values);

col_width  = 1.2;
row_height = 1.0;
line_xpad  = 1.;
fs         = 12;

% Column headers (param2 / markers)
for j = 1:n2
    cx = (j - 0.5) * col_width;
    text(ax_leg, cx, (n1 + 0.45) * row_height, param2_labels{j}, ...
        'HorizontalAlignment', 'center', ...
        'FontSize', fs, ...
        'Color', 'k', ...                         % headers stay neutral
        'FontWeight', 'bold', ...
        'Interpreter', 'latex');
end

% Rows: param1 label + swatches
for i = 1:n1
    cy = (n1 - i + 0.5) * row_height;

    text(ax_leg, -0.1, cy, param1_labels{i}, ...
        'HorizontalAlignment', 'right', ...
        'FontSize', fs, ...
        'Color', colors{i}, ...                   % row label colour matches Delta
        'Interpreter', 'latex');

    for j = 1:n2
        cx_mid   = (j - 0.5) * col_width;
        cx_left  = (j - 1)   * col_width + line_xpad;
        cx_right =  j        * col_width - line_xpad;
        % Line segment — colour follows Delta (legend row i)
        plot(ax_leg, [cx_left cx_right], [cy cy], ...
            'LineStyle', line_styles{i}, ...
            'Color',     colors{i}, ...           % <-- colour by Delta
            'LineWidth', 1.2);
        % Marker at centre
        plot(ax_leg, cx_mid, cy, ...
            'LineStyle',  'none', ...
            'Marker',     markers{j}, ...
            'Color',      colors{i}, ...
            'MarkerSize', 10);
    end
end

xlim(ax_leg, [-0.85  n2 * col_width + 0.05]);
ylim(ax_leg, [-0.2   (n1 + 1) * row_height]);

ax_leg.Visible   = 'on';
ax_leg.XTick     = [];
ax_leg.YTick     = [];
ax_leg.Box       = 'on';
ax_leg.LineWidth = 0.8;

%% ---- SAVE --------------------------------------------------------------
exportgraphics(gcf,'figures/s_curve.pdf','ContentType','vector');
fprintf('Saved s_curve.pdf\n');