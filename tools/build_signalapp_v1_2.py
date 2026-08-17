import os
import shutil
import stat

import vitis


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
XSA = os.path.join(ROOT, "structure.xsa")
SOURCE = os.path.join(ROOT, "vitisV2", "SignalAPP_V1_2", "src")
WORKSPACE = os.path.abspath(
    os.environ.get("SIGNAL_WORKSPACE", os.path.join(ROOT, "build", "vitis"))
)
PLATFORM = "Signal_V1_2"
APPLICATION = "SignalAPP_V1_2"
DOMAIN = "standalone_ps7_cortexa9_0"


def reset_workspace():
    build_root = os.path.join(ROOT, "build")
    common = os.path.commonpath((build_root, WORKSPACE))
    if os.path.normcase(common) != os.path.normcase(build_root):
        raise RuntimeError("SIGNAL_WORKSPACE must be inside the build directory")
    if os.path.isdir(WORKSPACE):
        shutil.rmtree(WORKSPACE, onexc=remove_readonly)
    os.makedirs(WORKSPACE, exist_ok=True)


def remove_readonly(function, path, _error):
    os.chmod(path, stat.S_IWRITE)
    function(path)


def copy_application_sources(destination):
    shutil.copytree(
        SOURCE,
        destination,
        dirs_exist_ok=True,
        ignore=shutil.ignore_patterns(".clangd", "app.yaml", "README.txt"),
    )


if not os.path.isfile(XSA):
    raise FileNotFoundError(XSA)

reset_workspace()
client = vitis.create_client()
client.set_workspace(path=WORKSPACE)

try:
    platform = client.create_platform_component(
        name=PLATFORM,
        hw_design=XSA,
        os="standalone",
        cpu="ps7_cortexa9_0",
        domain_name=DOMAIN,
        generate_dtb=False,
    )
    platform.build()

    platform_repo = os.path.join(
        WORKSPACE, PLATFORM, "export", PLATFORM
    )
    client.add_platform_repos(platform_repo)
    platform_xpfm = client.find_platform_in_repos(PLATFORM)

    application = client.create_app_component(
        name=APPLICATION,
        platform=platform_xpfm,
        domain=DOMAIN,
        template="empty_application",
    )
    copy_application_sources(
        os.path.join(WORKSPACE, APPLICATION, "src")
    )
    application.build()

    elf = os.path.join(WORKSPACE, APPLICATION, "build", APPLICATION + ".elf")
    if not os.path.isfile(elf):
        raise RuntimeError("Application ELF was not generated")

    print("PLATFORM_BUILD_PASS=" + platform_repo)
    print("APPLICATION_BUILD_PASS=" + elf)
finally:
    vitis.dispose()
