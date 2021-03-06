dThresh = 0.5 #Detect Threshold (minimum acceptable confidence)
oThresh = 0.5 #Overlap Threshold (maximum acceptable IoU)
@info "Testing all models with detectThresh = $dThresh, overlapThresh = $oThresh"

testimages = ["dog-cycle-car_nonsquare","dog-cycle-car"]
pretrained_list = [
                    YOLO.v2_tiny_416_COCO,
                    # YOLO.v2_608_COCO,
                    YOLO.v3_tiny_416_COCO,
                    YOLO.v3_320_COCO,
                    YOLO.v3_416_COCO,
                    YOLO.v3_608_COCO,
                    # YOLO.v3_spp_608_COCO
                    ]

header = ["Model" "loaded?" "load time (s)" "ran?" "run time (s)" "objects detected"]
table = Array{Any}(undef, length(pretrained_list), 6)
for (k, pretrained) in pairs(pretrained_list)
    global table
    modelname = string(pretrained)
    table[k,:] .= [modelname, false, "-", "-", "-", "-"]
    @testset "Pretrained Model: $modelname" begin
        global table

        t_load = @elapsed begin
            yolomod = pretrained(silent=true)
        end
        table[k, 2] = true
        table[k, 3] = round(t_load, digits=3)
        @info "$modelname: Loaded in $(round(t_load, digits=2)) seconds."

        batch = emptybatch(yolomod)
        for (j, imagename) in pairs(testimages)

            @info """Testing image "$imagename" """
            IMG = load(joinpath(@__DIR__,"images","$imagename.png"))
            resultsdir = joinpath(@__DIR__,"results",imagename)
            !isdir(resultsdir) && mkdir(resultsdir)
            batch[:,:,:,1], padding = prepareImage(IMG, yolomod)

            val, t_run, bytes, gctime, m = @timed res = yolomod(batch, detectThresh=dThresh, overlapThresh=oThresh);
            @test size(res,2) > 0
            table[k, 4] = true
            table[k, 5] = round(t_run, digits=4)
            table[k, 6] = size(res, 2)
            @info "$modelname: Ran in $(round(t_run, digits=2)) seconds. (bytes $bytes, gctime $gctime)"

            imgBoxes = drawBoxes(IMG, yolomod, padding, res)
            resfile = joinpath(resultsdir,"$(modelname).jpg")
            save(resfile, imgBoxes)
            @info "$modelname: View result: $resfile"

        end
    end
    GC.gc()
end
pretty_table(table, header)
@info "Times approximate. For more accurate benchmarking run ObjectDetector.benchmark()"


@testset "Custom cfg's" begin
    @testset "Valid non-square dimensions (512x384)" begin
        IMG = load(joinpath(@__DIR__,"images","dog-cycle-car.png"))
        yolomod = YOLO.v3_COCO(silent=true, cfgchanges=[(:net, 1, :width, 512), (:net, 1, :height, 384)])
        batch = emptybatch(yolomod)
        batch[:,:,:,1], padding = prepareImage(IMG, yolomod)
        res = yolomod(batch, detectThresh=dThresh, overlapThresh=oThresh) #run once
        @test size(res,2) > 0
    end
    @testset "Invalid non-square dimensions" begin
        IMG = load(joinpath(@__DIR__,"images","dog-cycle-car.png"))
        # invalid height
        @test_throws AssertionError YOLO.v3_COCO(silent=false, w=512, h=383)
        # invalid width
        @test_throws AssertionError YOLO.v3_COCO(silent=false, w=511, h=384)
    end
end
