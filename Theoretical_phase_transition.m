clc
clear 

fig = figure;
ax_main = axes('Position', [0.10 0.11 0.87 0.35]);
hold(ax_main, 'on');

line_styles = {'-', '--', ':'};

E = logspace(-1,11,10000);

N=1000;

range=logspace(-2,2,100);

i=0;
for N1=[3,30,300]
    i=i+1;
    j=0;
    for Delta=range
        j=j+1;

        E1_star=(sqrt((N-Delta*E).^2+4*Delta*N1*E)-(N-Delta*E))./(2*Delta);
        E2_star=E-E1_star;
            
        G=(N1*(N-N1)/N)*(1./E).*abs(E1_star/N1-E2_star/(N-N1));

        tau(j) = E(find(G >= 0.5 * G(end), 1, 'first'))/N;

    end
    semilogx(ax_main, range, tau, ...
            'LineStyle',        line_styles{i}, ...
            'Color',            'k', ...
            'LineWidth',        1.2);
end

ax_main.FontSize = 14;
xlabel(ax_main, '$\Delta$', 'Interpreter', 'latex', 'FontSize', 19);
ylabel(ax_main, 'inflection point', 'Interpreter', 'latex', 'FontSize', 19);
box(ax_main, 'on');
grid(ax_main, 'on');
ax_main.Layer   = 'top';
ax_main.XScale  = 'log';
ax_main.GridAlpha      = 0.4;
ax_main.GridLineStyle  = '--';

l={'$n_1\!=\!0.3\%\quad$', '$n_1\!=\!3.0\%\quad$', '$n_1\!=\!30\%\quad$'};
legend(l,'Interpreter', 'latex')


ax_main = axes('Position', [0.09 0.6 0.88 0.35]);
hold(ax_main, 'on');

line_styles = {'-', '--', ':'};

E = logspace(-1,11,10000);

N=1000;

range=1:N-1;

i=0;
for Delta=[0.1,1,10]
    i=i+1;
    j=0;
    for N1=range
        j=j+1;

        E1_star=(sqrt((N-Delta*E).^2+4*Delta*N1*E)-(N-Delta*E))./(2*Delta);
        E2_star=E-E1_star;
            
        G=(N1*(N-N1)/N)*(1./E).*abs(E1_star/N1-E2_star/(N-N1));

        tau(j) = max(G);
    end
    semilogx(ax_main, range/N, tau, ...
            'LineStyle',        line_styles{i}, ...
            'Color',            'k', ...
            'LineWidth',        1.2);
end

ax_main.FontSize = 14;
xlabel(ax_main, '$n_1$', 'Interpreter', 'latex', 'FontSize', 19);
ylabel(ax_main, 'maximal inequality', 'Interpreter', 'latex', 'FontSize', 19);
box(ax_main, 'on');
grid(ax_main, 'on');
ax_main.Layer   = 'top';
ax_main.XScale  = 'log';
ax_main.GridAlpha      = 0.4;
ax_main.GridLineStyle  = '--';

%% ---- SAVE --------------------------------------------------------------
exportgraphics(gcf,'figures/phase_transition.pdf','ContentType','vector');
fprintf('Saved phase_transition.pdf\n');