using LinearAlgebra, Random, Printf, Statistics
using Plots, BenchmarkTools, JSON

using AccurateArithmetic
using AccurateArithmetic.Test

output(x) = @printf "%.2e " x
err(val, ref) = min(1, max(eps(Float64), abs((val-ref)/ref)))

function accuracy_run(n, c1, c2, logstep, gen, funs, outfile)
    data = [Float64[] for _ in 1:(1+length(funs))]

    c = c1
    while c < c2
        i = 1
        (x, d, C) = gen(n, c)
        output(C)
        push!(data[i], C)

        for fun in funs
            i += 1
            r = fun(x...)
            ε = err(r, d)
            output(ε)
            push!(data[i], ε)
        end

        println()
        c *= logstep
    end

    open(outfile, "w") do f
        JSON.print(f, data)
    end
end

function accuracy_plot(labels, outfile, plotfile)
    data = JSON.parsefile(outfile)

    scatter(title="Error of summation algorithms",
            xscale=:log10, yscale=:log10,
            xlabel="Condition number",
            ylabel="Relative error")

    for i in 1:length(labels)
        scatter!(data[1], data[i+1], label=labels[i])
    end

    savefig(plotfile)
end

function perf(n1, n2, logstep)
    data = [Float64[] for _ in 1:10]

    n = n1
    while n < n2
        x = rand(n)
        output(n)
        push!(data[1], n)

        b = @benchmark sum($x)
        t = minimum(b.times) / n
        output(t)
        push!(data[2], t)

        b = @benchmark cascaded_eft($x, two_sum, Val(:scalar), Val(1))
        t = minimum(b.times) / n
        output(t)
        push!(data[3], t)

        b = @benchmark cascaded_eft($x, two_sum, Val(:scalar), Val(2))
        t = minimum(b.times) / n
        output(t)
        push!(data[4], t)

        println()
        N = Int(round(n*logstep))
        N = 32*div(N, 32)
        n = max(N, n+32)

        # plot_perf(data)
    end

    data
end

function plot_perf(data)
    p = plot(title="Performance of summation algorithms",
             xscale=:log10,
             xlabel="Vector size",
             ylabel="Time [ns/elem]")

    plot!(data[1], data[2], label="sum")
    plot!(data[1], data[3], label="oro, ushift=1")
    plot!(data[1], data[4], label="oro, ushift=2")

    display(p)
end


function mask_vs_scalar(N)
    data = [Float64[] for _ in 1:10]
    for n in N:N+8
        x = rand(n)
        output(n)
        push!(data[1], n)

        b = @benchmark cascaded_eft($x, two_sum, Val(:mask), Val(2))
        t = minimum(b.times) / n
        output(t)
        push!(data[2], t)

        b = @benchmark cascaded_eft($x, two_sum, Val(:scalar), Val(2))
        t = minimum(b.times) / n
        output(t)
        push!(data[3], t)

        println()
    end

    data
end


function plot_mvs(data)
    p = plot(title="Mask vs Scalar",
             xlabel="Vector size",
             ylabel="Time [ns/elem]")
    plot!(data[1], data[2], label="mask")
    plot!(data[1], data[3], label="scalar")
    display(p)
end

function run_tests()
    BenchmarkTools.DEFAULT_PARAMETERS.evals = 2

    println("Running quality tests...")

    outfile  = "sum_accuracy.json"
    plotfile = "sum_accuracy.pdf"
    function gen_sum(n, c)
        (x, d, c) = generate_sum(n, c)
        ((x,), d, c)
    end
    accuracy_run(100, 2., 1e45, 2.,
                 gen_sum,
                 (sum, sum_naive, sum_oro, sum_kbn),
                 outfile)
    accuracy_plot(("pairwise", "naive", "oro", "kbn"),
                  outfile, plotfile)

    outfile  = "dot_accuracy.json"
    plotfile = "dot_accuracy.pdf"
    function gen_dot(n, c)
        (x, y, d, c) = generate_dot(n, c)
        ((x, y), d, c)
    end
    accuracy_run(100, 2., 1e45, 2.,
                 gen_dot,
                 (dot, dot_naive, dot_oro),
                 outfile)
    accuracy_plot(("blas", "naive", "oro"),
                  outfile, plotfile)

    # sleep(5)

    # println("Running performance tests...")
    # data_perf = perf(32, 1e8, 1.1)
    # plot_perf(data_perf)
    # savefig("perf.svg")

    # sleep(5)

    # println("Comparing variants: 'mask' vs 'scalar'...")
    # data_mvs = mask_vs_scalar(32)
    # plot_mvs(data_mvs)
    # savefig("mvs.svg")
end

run_tests()