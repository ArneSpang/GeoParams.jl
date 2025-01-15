using Test
using Unitful
using GeoParams

@testset "ChemicalDiffusion" begin

    # test the diffusion data structure
    x1 = GeoParams.DiffusionData()
    @test isbits(x1)

    # test Rutile Hf data
    test_diff = DiffusionData(
        )
    # calculate D and test here
    D = ustrip(compute_D(test_diff))
    @test D == 0.0

    # test Rutile Hf data
    Hf_Rt_para = Rutile.Rt_Hf_Cherniak2007_Ξc();

    D =  ustrip(compute_D(Hf_Rt_para[1], T=1273.15K))
    @test D ≈ 1.06039e-21 atol = 1e-24

    Hf_Rt_perp = Rutile.Rt_Hf_Cherniak2007_⊥c();

    D =  ustrip(compute_D(Hf_Rt_perp[1], T=1273.15K))
    @test D ≈ 1.21560e-21 atol = 1e-24

end
