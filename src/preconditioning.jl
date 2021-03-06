#### LSP preconditioner ### THREADS and Nxy/Nz size determined for SPE10 specifically
function lsps_prec(P, E::SparseMatrixDIA{T}, n, x) where {T}
    result = similar(x)
    triLU_solve!(P, x, result) #result = P^-1*x
    tmp1 = copy(result)
    tmp2 = similar(x)
    for i in 1:n
        BLAS.gemv!('N', -one(T), E, tmp1, zero(T), tmp2) # tmp2 = E * tmp1
	triLU_solve!(P, tmp2, tmp1) # = tmp1 = -P^-1 * tmp2
        LinearAlgebra.axpy!(one(T), tmp1, result) #result += tmp1
    end
    return result
end
function create_Jp(J)
    Jidx = [2, 5, 8, 10, 12, 15, 18]
    Jp = SparseMatrixDIA([(J.diags[i].first>>1)=>J.diags[i].second[1:2:end] for i in Jidx], size(J,1)>>1, size(J,1)>>1)
    return Jp
end
function CPR_Setup!(J, P, E)
    Jidx = [2, 5, 8, 10, 12, 15, 18]
    Jp = SparseMatrixDIA([(J.diags[i].first>>1)=>J.diags[i].second[1:2:end] for i in Jidx], size(J,1)>>1, size(J,1)>>1)
    Pp = SparseMatrixDIA([Jp.diags[i].first=>copy(Jp.diags[i].second) for i in [3,4,5]], size(Jp)...)
    Ep = SparseMatrixDIA([Jp.diags[i].first=>Jp.diags[i].second for i in [1,2,6,7]], size(Jp)...)

    triLU!(P)
    triLU!(Pp)
    return Jp, Pp, Ep
end

function CPR_LSPS(J, P, E, Jp, Pp, Ep, RES, CPR_args, itercount)
    ## Page 3 of https://www.onepetro.org/download/journal-paper/SPE-106237-PA?id=journal-paper%2FSPE-106237-PA 
    xp = fgmres(Jp, RES[1:2:end], CPR_args[1];maxiter=CPR_args[2], M=(t->lsps_prec(Pp, Ep, CPR_args[4][1], t)), tol=CPR_args[3]) #(2)
    push!(itercount, xp[2])
    s = zero(RES)
    s[1:2:end] .+= xp[1] #(3)
    return s + lsps_prec(P, E, CPR_args[4][2], RES-J*s)
end

function CPR_MG(J, P, E, Jp, ml, RES, CPR_args, itercount)
    xp = fgmres(Jp, RES[1:2:end], CPR_args[1];maxiter=CPR_args[2], M=(t->DIA.solve!(zero(t), ml, t, (85,220,60), (1,2,2);maxiter=CPR_args[5])), tol=CPR_args[3])
    push!(itercount, xp[2])
    s = zero(RES)
    s[1:2:end] .+= xp[1]
    
    return s + lsps_prec(P, E, CPR_args[4], RES-J*s)
end
