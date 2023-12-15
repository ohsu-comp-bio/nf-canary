process TEST_SUCCESS {
    /*
    This process should automatically succeed
    */

    output:
        stdout

    script:
    """
    funnel run 'exit 0' --wait
    """
}

process TEST_CREATE_FILE {
    /*
    Creates a file on the worker node which is uploaded to the working directory.
    */

    output:
        path("*.txt"), emit: outfile

    """
    funnel run 'touch \$output' --stdout test.txt --out output=test.txt --wait --workdir /tmp
    """
}

process TEST_CREATE_FOLDER {
    /*
    Creates a file on the worker node which is uploaded to the working directory.
    */

    output:
        path("test"), type: 'dir', emit: outfolder

    """
    funnel run 'mkdir -p \$output
    touch \$output/test1.txt
    touch \$output/test2.txt' --out-dir output=test --wait --workdir /tmp
    """
}

process TEST_INPUT {
    /*
    Stages a file from the working directory to the worker node.
    */

    input:
        path input

    output:
        stdout

    """
    funnel run 'cat \$input' --in input=$input --wait --workdir /tmp
    """
}

process TEST_BIN_SCRIPT {
    /*
    Runs a script from the bin/ directory
    */

    input:
        path input

    output:
        path("*.txt")

    """
    funnel run 'sh \$input' --in input=$input --stdout test.txt --wait --workdir /tmp
    """
}

process TEST_STAGE_REMOTE {
    /*
    Stages a file from a remote file to the worker node.
    */

    input:
        path input

    output:
        stdout

    """
    funnel run 'cat \$input' --in input=$input --wait
    """
}

process TEST_PASS_FILE {
    /*
    Stages a file from the working directory to the worker node, copies it and stages it back to the working directory.
    */

    input:
        path input

    output:
        path "out.txt", emit: outfile

    """
    funnel run 'cp "\$input" "\$output"' --in input=$input --out output=out.txt --wait --workdir /tmp
    """
}

process TEST_PASS_FOLDER {
    /*
    Stages a folder from the working directory to the worker node, copies it and stages it back to the working directory.
    */

    input:
        path input

    output:
        path "out", type: 'dir', emit: outfolder

    """
    funnel run 'cp -rL "\$input" "\$output"' --in input=$input --out-dir output=out --wait --workdir /tmp 
    """
}

process TEST_PUBLISH_FILE {
    /*
    Creates a file on the worker node and uploads to the publish directory.
    */

    publishDir { params.outdir ?: file(workflow.workDir).resolve("outputs").toUriString()  }, mode: 'copy'

    output:
        path("*.txt")

    """
    export publishDir=${params.outdir ?: file(workflow.workDir).resolve("outputs").toUriString()}
    
    funnel run 'touch \$output' --out output=test.txt --wait --workdir \$publishDir
    """
}

process TEST_PUBLISH_FOLDER {
    /*
    Creates a file on the worker node and uploads to the publish directory.
    */

    publishDir { params.outdir ?: file(workflow.workDir).resolve("outputs").toUriString()  }, mode: 'copy'

    output:
        path("test", type: 'dir')

    """
    export publishDir=${params.outdir ?: file(workflow.workDir).resolve("outputs").toUriString()}
    
    funnel run 'mkdir -p \$output
    touch \$output/test1.txt
    touch \$output/test2.txt' --out-dir output=test --wait --workdir \$publishDir
    """
}


process TEST_IGNORED_FAIL {
    /*
    This process should automatically fail but be ignored.
    */
    errorStrategy 'ignore'

    output:
        stdout

    """
    funnel run 'exit 1' --wait
    """
}

process TEST_MV_FILE {
    /*
    This process moves a file within a working directory.
    */
    output:
        path "output.txt"

    """
    funnel run 'touch test.txt
    mv test.txt \$output' --out output=output.txt --wait --workdir /tmp
    """

}

process TEST_MV_FOLDER_CONTENTS {
    /*
    Moves the contents of a folder from within a folder
    */

    output:
        path "out", type: 'dir', emit: outfolder

    """
    funnel run 'mkdir -p test
    echo "test!" > test/test.txt
    mkdir -p \$output
    mv test/* \$output' --out-dir output=out --wait --workdir /tmp
    """
}

workflow NF_CANARY {

    main:
        // Create test file on head node
        Channel
            .of("alpha", "beta", "gamma")
            .collectFile(name: 'sample.txt', newLine: true)
            .set { test_file }

        remote_file = params.remoteFile ? Channel.fromPath(params.remoteFile) : Channel.empty()
        bin_file = Channel.fromPath('bin/run.sh')

        // Run tests
        TEST_SUCCESS()
        TEST_CREATE_FILE()
        TEST_CREATE_FOLDER()
        TEST_INPUT(test_file)
        TEST_BIN_SCRIPT(bin_file)
        TEST_STAGE_REMOTE(remote_file)
        TEST_PASS_FILE(TEST_CREATE_FILE.out.outfile)
        TEST_PASS_FOLDER(TEST_CREATE_FOLDER.out.outfolder)
        TEST_PUBLISH_FILE()
        TEST_PUBLISH_FOLDER()
        TEST_IGNORED_FAIL()
        TEST_MV_FILE()
        TEST_MV_FOLDER_CONTENTS()

        // POC of emitting the channel
        Channel.empty()
            .mix(
                TEST_SUCCESS.out,
                TEST_CREATE_FILE.out,
                TEST_CREATE_FOLDER.out,
                TEST_INPUT.out,
                TEST_BIN_SCRIPT.out,
                TEST_STAGE_REMOTE.out,
                TEST_PASS_FILE.out,
                TEST_PASS_FOLDER.out,
                TEST_PUBLISH_FILE.out,
                TEST_PUBLISH_FOLDER.out,
                TEST_IGNORED_FAIL.out,
                TEST_MV_FILE.out,
                TEST_MV_FOLDER_CONTENTS.out
            )
            .set { ch_out }

    emit:
        out = ch_out
}

workflow {
    NF_CANARY()
}