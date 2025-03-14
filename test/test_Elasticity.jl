using Test
using GeoParams

@testset "Elasticity.jl" begin

    # This tests the MaterialParameters structure
    CharUnits_GEO = GEO_units(; viscosity = 1.0e19, length = 10km)

    # ConstantElasticity ---------
    a = ConstantElasticity()
    info = param_info(a)
    @test isbits(a)
    @test NumValue(a.G) == 5.0e10
    @test repr("text/plain", a) isa String

    a_nd = a
    a_nd = nondimensionalize(a_nd, CharUnits_GEO)
    @test a_nd.G.val ≈ 5000.0

    a = SetConstantElasticity(; Kb = 5.0e10, ν = 0.43)
    @test Value(a.E) ≈ 2.1e10Pa

    a = SetConstantElasticity(; G = 5.0e10, ν = 0.43)
    @test Value(a.E) ≈ 1.43e11Pa

    a = SetConstantElasticity(; G = 5.0e10, Kb = 1.0e11)
    @test Value(a.E) ≈ 1.2857142857142856e11Pa

    @test isvolumetric(a) == true

    b = ConstantElasticity()
    v = SetMaterialParams(; CompositeRheology = CompositeRheology((ConstantElasticity(),)))
    vv = (
        SetMaterialParams(; Phase = 1, CompositeRheology = CompositeRheology((ConstantElasticity(),))),
        SetMaterialParams(; Phase = 2, CompositeRheology = CompositeRheology((ConstantElasticity(),))),
    )

    @test get_G(b) == b.G.val
    @test get_G(v) == b.G.val
    @test get_G(vv, 1) == get_G(vv, 2) == b.G.val # for multiple phases

    @test get_Kb(b) == b.Kb.val
    @test get_Kb(v) == b.Kb.val
    @test get_Kb(vv, 1) == get_Kb(vv, 2) == b.Kb.val # for multiple phases

    # Test get_G and get_Kb with a composite rheology
    v1 = SetDiffusionCreep(Diffusion.dry_anorthite_Rybacki_2006) # SetPeierlsCreep("Dry Olivine | Goetze and Evans (1979)")
    v2 = SetDislocationCreep(Dislocation.dry_anorthite_Rybacki_2006)
    e1 = ConstantElasticity()           # elasticity
    # CompositeRheologies
    c = CompositeRheology(v1, v2, e1)   # with elasticity

    r = SetMaterialParams(;
        CompositeRheology = c
    )

    @test get_G(c) == get_G(r) == r.CompositeRheology[1].elements[3].G.val
    @test get_Kb(c) == get_Kb(r) == r.CompositeRheology[1].elements[3].Kb.val

    # Compute with Floats
    τII = 20.0e6
    τII_old = 15.0e6
    p = 10.0e6
    P_old = 5.0e6
    dt = 1.0e6
    argsτ = (τII_old = τII_old, dt = dt)
    argsp = (P_old = P_old, dt = dt)
    @test compute_εII(a, τII, argsτ) ≈ 5.0e-11  # compute
    @test compute_τII(a, 1.0e-15, argsτ) ≈ 1.50001e7
    @test compute_εvol(a, p, argsp) ≈ -5.0e-11  # compute
    @test compute_p(a, 1.0e-15, argsp) ≈ 4.9999e6
    @test dεII_dτII(a, τII, argsτ) ≈ 1.0e-17
    @test dτII_dεII(a, τII_old, dt, argsτ) ≈ 1.0e17
    @test dεvol_dp(a, p, argsp) ≈ -1.0e-17
    @test dp_dεvol(a, P_old, dt, argsp) ≈ -1.0e17

    # Test with arrays
    τII_old_array = ones(10) * 15.0e6
    τII_array = ones(10) * 20.0e6
    ε_el_array = similar(τII_array)
    p_old_array = ones(10) * 20.0e6
    p_array = ones(10) * 26.0e6
    εvol_el_array = similar(p_array)
    argsτ = (τII_old = τII_old_array, dt = dt)
    argsp = (P_old = p_old_array, dt = dt)
    compute_εII!(ε_el_array, a, τII_array, argsτ)
    @test ε_el_array[1] ≈ 5.0e-11
    compute_εvol!(εvol_el_array, a, p_array, argsp)
    @test εvol_el_array[1] ≈ -6.0e-11
    compute_τII!(τII_array, a, ε_el_array, argsτ)
    @test τII_array[1] ≈ 2.0e7
    compute_p!(p_array, a, εvol_el_array, argsp)
    @test p_array[1] ≈ 2.6e7

    #=
    # Check that it works if we give a phase array
    MatParam = (
        SetMaterialParams(; Name="Mantle", Phase=1, Elasticity=ConstantElasticity()),
        SetMaterialParams(;
            Name="Crust", Phase=2, Elasticity=ConstantElasticity(; G=1e10Pa)
        ),
        SetMaterialParams(;
            Name="Crust", Phase=2, HeatCapacity=ConstantHeatCapacity(; Cp=1100J / kg / K)
        ),
    )

    # test computing material properties
    n = 100
    Phases = ones(Int64, n, n, n)
    Phases[:, :, 20:end] .= 2
    Phases[:, :, 60:end] .= 2

    τII      =  ones(size(Phases))*20e6;
    τII_old  =  ones(size(Phases))*15e6;
    ε_el = zero(τII);
    args = (τII_old=τII_old, dt=1e6);
    compute_εII!(ε_el, MatParam, Phases, τII, args)    # computation routine w/out P (not used in most heat capacity formulations)
    @test maximum(ε_el[1,1,:]) ≈ 2.5e-10

    # test if we provide phase ratios
    PhaseRatio = zeros(n, n, n, 3)
    for i in CartesianIndices(Phases)
        iz = Phases[i]
        I = CartesianIndex(i, iz)
        PhaseRatio[I] = 1.0
    end

    # Note; using PhaseRatio currently requires an array of timesteps - can probably be fixed to also allow scalars
    dt_arr   =  ones(size(Phases))*1e6;     # needs to be an array of timesteps currently
    args = (τII=τII, τII_old=τII_old, dt=dt_arr);
    compute_εII!(ε_el, MatParam, PhaseRatio, args)
    @test maximum(ε_el[1,1,:]) ≈ 2.5e-10

    args1 = (τII=τII, τII_old=τII_old, dt=1e6);
    compute_εII!(ε_el, MatParam, PhaseRatio, args1)
    @test maximum(ε_el[1,1,:]) ≈ 2.5e-10

    num_alloc = @allocated compute_εII!(ε_el, MatParam, PhaseRatio, args)
    @test maximum(ε_el[1,1,:]) ≈ 2.5e-10
    @test num_alloc <= 32

    # -----------------------
    =#

end
