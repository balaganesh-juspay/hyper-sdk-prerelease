require 'net/http'
require 'fileutils'
require 'logger'
require 'json'

$is_devtools_build = false
is_xcodeproj_available = true

begin
    require 'xcodeproj'
rescue LoadError
    is_xcodeproj_available = false
end

class String
    def red;            "\e[31m#{self}\e[0m" end
    def green;          "\e[32m#{self}\e[0m" end
    def yellow;         "\e[33m#{self}\e[0m" end
end

$verboseEnabled = false
$downloadInParallel = true

class AssetsDownloadWorker
    def self.start(download_status:,files_count:, verbose:, downloadInParallel:, index:)
        queue = SizedQueue.new(files_count)
        num_threads = 0
        if $downloadInParallel == true
            num_threads = 15
        end
        worker = new(num_threads: num_threads, queue: queue, verbose: verbose,download_status: download_status, index: index)
        worker.spawn_threads
        worker
    end

    def initialize(num_threads:, queue:, verbose:,download_status:,index:)
        @num_threads = num_threads
        @queue = queue
        @download_status = download_status
        @index = index
        @threads = []
        @files_downloaded = 0
        @actions_finished = 0
        @verbose = verbose
    end

    attr_reader :num_threads, :threads, :queue

    attr_reader :files_downloaded, :actions_finished

    def spawn_threads
        num_threads.times do
            threads << Thread.new() {
                while running? || actions?
                    payload = wait_for_action
                    download_assets(payload) if payload
                end
            }
        end
    end

    def download_assets(payload)
        logger = Logger.new(STDOUT)
        file = payload["file"]
        file_data = file.gsub!(/\s/, '').split("@", 2)
        file_name = file_data[0].split("/")[2]
        file_path = payload["iphoneFrameworkPath"] + file_name
        file_path_simulator = payload["simulatorFrameworkPath"] + file_name
        file_url = file_data[1]
        is_xcframework = payload["isXCFramework"]

        if (@verbose)
            logger.info("[HyperSDK] downloading file: #{file_url}")
        end

        url = URI.parse(file_url)
        req = Net::HTTP::Get.new(url.path)
        if File.exist?(file_path) && file_name != "v1-boot_loader.jsa"
            time = (File.mtime(file_path)).gmtime
            gmt = time.strftime("%a, %d %b %Y %H:%M:%S GMT")
            req.add_field("If-Modified-Since", gmt)
        end

        begin
            res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
                http.request(req)
            end
            if (@verbose)
                logger.info("[HyperSDK] File Response message: #{res.message}")
            end

            if res.code == '304'
            elsif res.code == '403'
                @download_status[@index] = false
                logger.error("[HyperSDK] Error downloading file: #{file_url} #{res.code}")
            elsif res.code == '200'
                @files_downloaded += 1
                File.open(file_path, 'w') do |f|
                    f.write res.body
                end
                if is_xcframework
                    File.open(file_path_simulator, 'w') do |f|
                        f.write res.body
                    end
                end
            else
                puts ("[HyperSDK] Error downloading file: " + file_url + " " + res.code).red
                @download_status[@index] = false
            end
        rescue StandardError => e
            @download_status[@index] = false
            logger.fatal("[HyperSDK] Crashed while downloading file: #{e} #{file_url}")
        end
        @actions_finished += 1
    end

    def enqueue(payload)
        queue.push(payload)
    end

    def stop
        queue.close
        threads.each(&:exit)
        threads.clear
        true
    end

    def actions?
        !queue.empty?
    end

    def running?
        !queue.closed?
    end

    def dequeue_action
        queue.pop(true)
    end

    def wait_for_action
        queue.pop(false)
    end
end


merchant_config_data = {
    "env" => "production",
    "scope" => "release"
}

$tenant_params = nil
if(ARGV.length>2)
    begin
        $tenant_params = JSON.parse(ARGV[2])
    rescue JSON::ParserError => e
    end
end
if ($tenant_params == nil)
    val = {
        resource_url: "https://public.releases.juspay.in/hyper/bundles/in.juspay.merchants/%@client_id/ios/release/assets.zip",
        sandbox_resource_url: "https://sandbox.assets.juspay.in/hyper/bundles/in.juspay.merchants/%@client_id/ios/release/assets.zip",
        versioned_resource_url: "https://assets.juspay.in/hyper-sdk/in/juspay/merchants/hyper.assets.%@client_id/%@asset_version/hyper.assets.%@client_id-%@asset_version.zip",
        merchant_config_json: "MerchantConfig.json",
        tenant_id: "juspay"
    }
    $tenant_params = JSON.parse(JSON.generate(val))
end

merchant_config_path = "./MerchantConfig.txt"
merchant_config_json = "./#{$tenant_params["merchant_config_json"]}"
if File.exist?(merchant_config_json)
    json_data = File.read(merchant_config_json)
    merchant_config_data = JSON.parse(json_data)

elsif File.exist?(merchant_config_path)
    File.foreach(merchant_config_path) { |line|
        rawLine = line.gsub!(/\s/, '')
        if rawLine != nil
            line = rawLine
        end
        key_value = line.split("=", 2)
        if key_value[0] && key_value[1]
            merchant_config_data[key_value[0]] = key_value[1]
        end
    }
else
    puts "[HyperSDK] Error - MerchantConfig.txt or MerchantConfig.json file not found. Put it in the folder where Podfile is present.".red
    return
end

pListTargets = []
if (merchant_config_data["pListTargets"])
    pListTargets = merchant_config_data["pListTargets"].split(",")
end

def to_boolean(str)
    str.to_s.downcase == 'true'
end

if (merchant_config_data["verbose"])
    $verboseEnabled = to_boolean(merchant_config_data["verbose"])
end

if (merchant_config_data["downloadInParallel"])
    $downloadInParallel = to_boolean(merchant_config_data["downloadInParallel"])
end
# clientIds = []
if(merchant_config_data["clientConfigs"])
    clientIds = merchant_config_data["clientConfigs"]
elsif(merchant_config_data["clientId"])
    clientIds = {"#{merchant_config_data["clientId"]}":{
        "assetVersion": merchant_config_data["assetVersion"],
        "scope": merchant_config_data["scope"].split("_")[0],
        "env": merchant_config_data["env"].split("_")[0],
        "version": merchant_config_data["version"]
    }}
else
    return
end

$os = "ios"


$clean_assets = ARGV.length > 0 && ARGV[0] == "true"
$is_xcframework = ARGV.length > 1 && ARGV[1] == "xcframework" && (! $is_devtools_build)




puts ("[HyperSDK] Is Xcframework? - No").yellow if !$is_xcframework



hyper_sdk_framework_path =$is_xcframework ? "./Pods/HyperSDK/HyperSDK.xcframework" : "./Pods/HyperSDK/HyperSDK.framework"
$assets_path = $is_xcframework ? hyper_sdk_framework_path + "/*/*" : hyper_sdk_framework_path

$hyper_sdk_iphone_framework_path =  hyper_sdk_framework_path + ($is_xcframework ? "/ios-arm64/HyperSDK.framework/" : "/")
$hyper_sdk_simulator_framework_path = hyper_sdk_framework_path + "/ios-arm64_x86_64-simulator/HyperSDK.framework/"
if $is_devtools_build
    hyper_sdk_framework_path = "./lib/HyperSDK"
    $assets_path = hyper_sdk_framework_path

    $hyper_sdk_iphone_framework_path =  "./lib/HyperSDK/Assets/Bundles/"
    $hyper_sdk_simulator_framework_path = "./lib/HyperSDK/Assets/Bundles/"
end
def get_bundled_path(source_path,bundle_path)
    if bundle_path == ""
        return source_path
    end
    return source_path + bundle_path + "/"
end

def get_hyper_sdk_version()
    plist_path = File.join($hyper_sdk_iphone_framework_path, "Info.plist")

    if File.exist?(plist_path)
        info_plist = File.read(plist_path) # read binary plist
        IO.popen('plutil -convert xml1 -r -o - -- -', 'r+') {|f|
            f.write(info_plist)
            f.close_write
            info_plist = f.read # xml plist
        }
        version = info_plist.scan(/<key>hyper_sdk_version<\/key>\s+<string>(.+)<\/string>/).flatten.first

        if version
            return version
        else
            puts "[HyperSDK] hyper_sdk_version key not found"
        end
    else
        puts "[HyperSDK] Info.plist not found at #{plist_path}"
    end
    return nil
end

$hyper_sdk_version = get_hyper_sdk_version()

puts "[HyperSDK] HyperSDK version - #{$hyper_sdk_version}".yellow

def should_add_verify_assets_file(bundle_name)
    if $hyper_sdk_version == "2.2.0" # Forcefully failing for 2.2.0
        return false
    end

    if $hyper_sdk_version == nil || (Gem::Version.new($hyper_sdk_version) < Gem::Version.new("2.2.0"))
        return true
    end

    required_files = ["app-config.json", "app-pkg.json", "app-resources.json"]

    iphone_files_exist = required_files.all? do |file|
        File.exist?(File.join(get_bundled_path($hyper_sdk_iphone_framework_path,bundle_name), file))
    end

    simulator_files_exist = required_files.all? do |file|
        File.exist?(File.join(get_bundled_path($hyper_sdk_simulator_framework_path,bundle_name), file))
    end

    return iphone_files_exist && simulator_files_exist
end

def add_verify_assets_file(bundle_name)
    if should_add_verify_assets_file(bundle_name)
        FileUtils.mv(get_bundled_path($hyper_sdk_iphone_framework_path,bundle_name) + "VerifyHyperAssets.h", $hyper_sdk_iphone_framework_path + "Headers")
        if $is_xcframework
            FileUtils.mv(get_bundled_path($hyper_sdk_simulator_framework_path,bundle_name) + "VerifyHyperAssets.h", $hyper_sdk_simulator_framework_path + "Headers")
        end
        return true
    end
    return false
end

if(! $is_devtools_build)
    FileUtils.rm_rf(Dir[ $assets_path + "/VerifyHyperAssets.h" ])
    FileUtils.rm_rf(Dir[ $assets_path + "/Headers/VerifyHyperAssets.h" ])
end

def delete_assets(asset_path)
    if(! $is_devtools_build)
        FileUtils.rm_rf(Dir[ asset_path + "/*.mp3" ])
        FileUtils.rm_rf(Dir[ asset_path + "/app-*.json" ])
        FileUtils.rm_rf(Dir[ asset_path + "/*.png" ])
        FileUtils.rm_rf(Dir[ asset_path + "/*.ttf" ])
        FileUtils.rm_rf(Dir[ asset_path + "/*.xml" ])
        FileUtils.rm_rf(Dir[ asset_path + "/payments-*.jsa" ])
        FileUtils.rm_rf(Dir[ asset_path + "/payments-in.juspay.vies-vies*" ])
        FileUtils.rm_rf(Dir[ asset_path + "/v1-config.jsa" ])
        FileUtils.rm_rf(Dir[ asset_path + "/v1-boot_loader.jsa" ])
        FileUtils.rm_rf(Dir[ asset_path + "/juspay_assets.json" ])
        FileUtils.rm_rf(Dir[ asset_path + "/payments-in.juspay.hyperpay-*.json" ])
    end
end

def extract_to_path(zip_path,destination_path, merchant_id)
    puts "[HyperSDK] #{merchant_id} Extracting assets..."
    system("unzip", "-q", "-o", "-j", zip_path, "-d", get_bundled_path($hyper_sdk_iphone_framework_path , destination_path))
    if $is_xcframework
        system("unzip", "-q", "-o", "-j", zip_path, "-d", get_bundled_path($hyper_sdk_simulator_framework_path , destination_path))
    end
end


def get_bundle_name(merchant_id,is_multi_client)
    if (is_multi_client || $tenant_params["tenant_id"] != "juspay")
        return $tenant_params["tenant_id"] + "-" + merchant_id + ".bundle"
    else
        return ""
    end
end

def download_asset_zip(merchant_id,index,download_status,value)
    env = value["env"].split("_")[0]
    puts ("[HyperSDK] (#{merchant_id})  Environment - " + env).yellow if env != "production"
    asset_zip_template = env == "sandbox"? $tenant_params['sandbox_resource_url'] : $tenant_params['resource_url']
    asset_zip_url = asset_zip_template.sub("%@client_id",merchant_id)
    if (value["assetVersion"])
        asset_zip_url = $tenant_params["versioned_resource_url"].sub("%@client_id",merchant_id).sub("%@asset_version",versioned_resource_url);
    end

    puts "[HyperSDK] (#{merchant_id}) Downloading assets from: " + asset_zip_url

    uri = URI.parse(asset_zip_url)
    response = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
    end
    bundle_name = get_bundle_name(merchant_id, download_status.length >1)
    if $clean_assets || response.code == '200'
        delete_assets(get_bundled_path($assets_path,bundle_name))
    end
    if response.code == '200'

        local_zip_file = merchant_id + '.zip'
        File.open(local_zip_file, 'wb') do |file|
            file.write(response.body)
        end
        puts "[HyperSDK] (#{merchant_id}) Download complete!"
        extract_to_path(local_zip_file,bundle_name, merchant_id)

        if !should_add_verify_assets_file(bundle_name)
            puts "[HyperSDK] (#{merchant_id}) Error - Required files are missing!".red
            download_status[index] = false
            return
        end

        FileUtils.rm(local_zip_file)
    elsif $tenant_params["tenant_id"] !="juspay"
        download_status[index] = false
        return
    else
        temp_dir_name = "juspay#{merchant_id}"
        puts "[HyperSDK] (#{merchant_id}) Error downloading zip file: #{response.code} - #{response.message}"

        FileUtils.mkdir_p temp_dir_name


        versionPart = value["version"] ? "/" + value["version"] : ""
        filePart = '/AssetConfig.txt'
        scope = value["scope"].split("_")[0]
        puts ("[HyperSDK] (#{merchant_id}) Scope - " + scope).yellow if scope != "release"
        scopePart = (scope == "beta" ? "beta/" : (scope == "cug") ? "cug/" : "")
        domain = env == "sandbox" ? "https://sandbox.assets.juspay.in" : "https://assets.juspay.in"
        url = URI.parse(domain + '/hyper/assetConfig/' + $os + '/' + scopePart + merchant_id + versionPart + filePart)
        req = Net::HTTP::Get.new(url.path)
        res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
            http.request(req)
        end

        asset_config_path = "#{temp_dir_name}/AssetConfig.txt"

        if res.code == '200'
            File.open(asset_config_path, 'w') do |f|
                f.write res.body
            end
        else
            download_status[index] = false
            puts ("[HyperSDK] (#{merchant_id}) Error downloading AssetConfig #{domain + '/hyper/assetConfig/' + $os + '/' + scopePart + merchant_id + versionPart + filePart}- " + res.code ).red
            return
        end

        files_to_download = []

        if File.exist?(asset_config_path)
            File.foreach(asset_config_path) { |line|
                files_to_download.push(line)
            }
        end

        files_to_download.push('HyperAssets/payments/VerifyHyperAssets.h @ https://public.releases.juspay.in/hypersdk-asset-download/ios/VerifyHyperAssets.h');

        iphoneFrameworkPath = get_bundled_path($hyper_sdk_iphone_framework_path,bundle_name)
        simulatorFrameworkPath = get_bundled_path($hyper_sdk_simulator_framework_path,bundle_name)
        unless Dir.exist?(iphoneFrameworkPath)
            Dir.mkdir(iphoneFrameworkPath)
        end
        unless Dir.exist?(simulatorFrameworkPath)
            Dir.mkdir(simulatorFrameworkPath)
        end
        worker_instance = AssetsDownloadWorker.start(files_count: files_to_download.length, verbose: $verboseEnabled, downloadInParallel: $downloadInParallel,download_status: download_status,index: index)

        puts "[HyperSDK] (#{merchant_id}) Downloading assets..."

        files_to_download.each do |file|
            if ($downloadInParallel == true)
                worker_instance.enqueue({ "file" => file,
                                            "iphoneFrameworkPath" => iphoneFrameworkPath,
                                            "simulatorFrameworkPath" => simulatorFrameworkPath,
                                            "isXCFramework" => $is_xcframework })
            else
                worker_instance.download_assets({ "file" => file,
                                                "iphoneFrameworkPath" => iphoneFrameworkPath,
                                                "simulatorFrameworkPath" => simulatorFrameworkPath,
                                                "isXCFramework" => $is_xcframework })
            end
        end

        until files_to_download.length == worker_instance.actions_finished
            sleep 1
        end

        puts "[HyperSDK] (#{merchant_id}) #{worker_instance.files_downloaded - 1} file(s) downloaded/updated."

        worker_instance.stop

        if !should_add_verify_assets_file(bundle_name)
            puts "[HyperSDK] (#{merchant_id}) Error - Required files are missing!".red
            download_status[index] = false
            return
        end

        FileUtils.rm_rf(temp_dir_name)
    end
end
threads = []
download_status = Array.new(clientIds.length,true)
clientIds.each_with_index do |(merchant_id,value), index|
    value["scope"] = value["scope"] ? value["scope"] : "release"
    value["env"] = value["env"] ? value["env"]: "production"
    threads << Thread.new do
        download_asset_zip(merchant_id.to_s, index, download_status,value)
    end
end

threads.each(&:join)


if download_status.all?
    clientIds.each_with_index do |clientConfig, index|
        bundle_name = get_bundle_name(clientConfig[0],download_status.length>1)
        if (index == 0 && (! $is_devtools_build))
            add_verify_assets_file(bundle_name)
        else
            FileUtils.rm(get_bundled_path($hyper_sdk_iphone_framework_path,bundle_name) + "VerifyHyperAssets.h")
            if $is_xcframework
                FileUtils.rm(get_bundled_path($hyper_sdk_simulator_framework_path,bundle_name) + "VerifyHyperAssets.h")
            end
        end
    end

end

puts "[HyperSDK] Done.".green