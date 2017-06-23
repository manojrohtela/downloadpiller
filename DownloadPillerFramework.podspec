Pod::Spec.new do |s|
          #1.
          s.name               = “DownloadPillerFramework”
          #2.
          s.version            = "1.0.0"
          #3.  
          s.summary         = “sample framework”
          #4.
          s.homepage        = "http://www.iosmind.com”
          #5.
          s.license              = "MIT"
          #6.
          s.author               = “IOS dev“
          #7.
          s.platform            = :ios, "10.0"
          #8.
          s.source              = { :git => "https://github.com/manojrohtela/downloadpiller.git", :tag => "1.0.0" }
          #9.
          s.source_files     = "DownloadPillerFramework", "DownloadPillerFramework/**/*.{h,m,objectiveC}”
    end