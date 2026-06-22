%% ========================================================================
%  Pareto tail emergence from QRE with Beta-distributed rationality
%  EXACT sampling from the constrained joint
%      p(x) ∝ exp(sum_i lambda_i x_i) * delta(sum_i x_i - E),  x_i >= 0
%  via pair-Gibbs on the simplex.  This avoids the mean-field
%  approximation of treating x_i as independent exponentials and instead
%  samples directly from the original LQRE distribution.
%  ========================================================================

clear; clc; close all;
if ~exist('figures', 'dir'); mkdir('figures'); end

%% --- Parameters --------------------------------------------------------
N        = 1e6;        % number of agents
a        = 3;          % Beta(a, b) first shape
b        = 1.6;        % Beta(a, b) second shape == predicted tail exponent
n_sweeps = 1000;        % pair-Gibbs sweeps; each sweep = N/2 pair updates
rng(42);

%% --- Sample rationality and pick total resource ------------------------
lambdas = betarnd(a, b, N, 1);
% Match mean-field chemical potential to upper edge mu = 1:
%   <1/(mu - lambda)> = e  =>  for lambda~Beta(a,b), b>1: e = (a+b-1)/(b-1)
e_target = (a + b - 1) / (b - 1);
E        = e_target * N;
fprintf('N = %d, Beta(%d, %.1f), e = %.3f, E = %g\n', N, a, b, e_target, E);

%% --- Pair-Gibbs on the constrained simplex -----------------------------
% Initialize uniformly on the simplex {sum x = E, x >= 0}.
x = E * (-log(rand(N,1)));   % exponential surrogate
x = x / sum(x) * E;          % rescale to sum E (Dirichlet(1,...,1) * E)

fprintf('Running %d Gibbs sweeps...\n', n_sweeps);
for sweep = 1:n_sweeps
    perm = randperm(N);
    if mod(N, 2) == 1, perm = perm(1:end-1); end
    i_arr = perm(1:2:end);
    j_arr = perm(2:2:end);
    c_arr = x(i_arr) + x(j_arr);
    r_arr = lambdas(j_arr) - lambdas(i_arr);
    u_arr = rand(numel(i_arr), 1);
    new_xi = trunc_exp_sample(c_arr, r_arr, u_arr);
    x(i_arr) = new_xi;
    x(j_arr) = c_arr - new_xi;
end
fprintf('Done.  sum(x) - E = %.3e  (should be ~0)\n', sum(x) - E);

%% --- Tail diagnostics --------------------------------------------------
x_sorted = sort(x);
S        = (N:-1:1)' / N;

% Hill estimator on top 1%
k = round(N/100);
alpha_hill = 1 / mean(log(x_sorted(end-k+1:end) / x_sorted(end-k)));
fprintf('Hill (top 10%%) = %.3f  (predicted b = %.2f)\n', alpha_hill, b);

% Pareto reference, anchored at the 99th percentile
xq99     = quantile(x, 0.9);
C        = xq99^(b-.1) * 0.1;
x_ref    = logspace(log10(xq99), log10(max(x_sorted)), 200);
S_pareto = C ./ x_ref.^(b-.1);

% --- Plot --------------------------------------------------------------
fig_blue   = [0.00 0.45 0.74];
fig_orange = [0.85 0.33 0.10];

f = figure('Position', [100 100 800 520]);
hold on;
loglog(x_sorted, S, '-', 'Color', 'k', 'LineWidth', 1.5);
loglog(x_ref, S_pareto, '--', 'Color', 'k', 'LineWidth', 1.8);
 set(gca, 'XScale', 'log', 'YScale', 'log');
xl=xline(xq99, '-', '90th percentile', 'Color', [0.5 0.5 0.5], 'FontSize', 16);
xl.LabelVerticalAlignment = 'middle';
xl.LabelHorizontalAlignment = 'center';

xlabel('$x_i$', 'Interpreter','latex', 'FontSize', 20);
ylabel('complementary cumulative distribution function', 'Interpreter','latex', 'FontSize', 20);
title(sprintf('$\\lambda \\sim$ Beta$(%d, %.1f),\\ N = %d,\\ E=%d$', a, b, N,round(E)), ...
      'Interpreter','latex', 'FontSize', 16);
legend({'Numerical', ...
        sprintf('$P \\propto x_i^{-%.1f}$', b-.1)}, ...
       'Interpreter','latex', 'Location','southwest', 'FontSize', 16);
grid on; box on;
% set(gca, 'FontSize', 13);
xlim([quantile(x, 0.01), 1e3]);
set([gca().XAxis, gca().YAxis], 'FontSize', 16);

exportgraphics(f, 'figures/qre_beta_pareto.pdf', 'ContentType','vector');
fprintf('Figure saved.\n');

%% ------------------------------------------------------------------ %%
%  Truncated-exponential sampler:  y ~ exp(-r y) / Z  on  [0, c].
%  Vectorised, numerically stable for any sign and magnitude of r*c.
%  ------------------------------------------------------------------ %%
function y = trunc_exp_sample(c, r, u)
    s  = abs(r);
    sc = s .* c;
    z  = zeros(size(c));

    near_zero = s < 1e-12;
    z(near_zero) = u(near_zero) .* c(near_zero);

    normal = (~near_zero) & (sc <= 50);
    z(normal) = -log1p( u(normal) .* expm1(-sc(normal)) ) ./ s(normal);

    large = (~near_zero) & (sc > 50);
    z(large) = -log1p(-u(large)) ./ s(large);
    z(large) = min(z(large), c(large));

    y = z;
    neg = r < 0;
    y(neg) = c(neg) - z(neg);
end
