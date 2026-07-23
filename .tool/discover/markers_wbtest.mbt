// DirEntry classification convention used below:
//   real directory : is_dir = true,  is_file = false
//   regular file   : is_dir = false, is_file = true
//   symlink/special: is_dir = false, is_file = false  (invisible to discovery)

///|
test "is_apm_package_dir" {
  assert_eq(
    is_apm_package_dir([{ name: ".apm", is_dir: true, is_file: false }]),
    true,
  )
  // a file (not a directory) named `.apm` is not the marker.
  assert_eq(
    is_apm_package_dir([{ name: ".apm", is_dir: false, is_file: true }]),
    false,
  )
  // a symlink named `.apm` is invisible, so not the marker.
  assert_eq(
    is_apm_package_dir([{ name: ".apm", is_dir: false, is_file: false }]),
    false,
  )
  assert_eq(
    is_apm_package_dir([{ name: "apm.yml", is_dir: false, is_file: true }]),
    false,
  )
  assert_eq(is_apm_package_dir([]), false)
}

///|
test "has_apm_manifest" {
  assert_eq(
    has_apm_manifest([{ name: "apm.yml", is_dir: false, is_file: true }]),
    true,
  )
  assert_eq(
    has_apm_manifest([{ name: "apm.yaml", is_dir: false, is_file: true }]),
    true,
  )
  // a directory named apm.yml is not a manifest.
  assert_eq(
    has_apm_manifest([{ name: "apm.yml", is_dir: true, is_file: false }]),
    false,
  )
  // a symlink named apm.yml is invisible, so not a manifest.
  assert_eq(
    has_apm_manifest([{ name: "apm.yml", is_dir: false, is_file: false }]),
    false,
  )
  assert_eq(
    has_apm_manifest([{ name: ".apm", is_dir: true, is_file: false }]),
    false,
  )
}

///|
test "is_hook_package_dir" {
  assert_eq(
    is_hook_package_dir([{ name: "hooks", is_dir: true, is_file: false }]),
    true,
  )
  // a file named `hooks` is not the marker.
  assert_eq(
    is_hook_package_dir([{ name: "hooks", is_dir: false, is_file: true }]),
    false,
  )
  assert_eq(
    is_hook_package_dir([{ name: "hook.json", is_dir: false, is_file: true }]),
    false,
  )
}

///|
test "is_marketplace_plugin_dir" {
  assert_eq(
    is_marketplace_plugin_dir([
      { name: "plugin.json", is_dir: false, is_file: true },
    ]),
    true,
  )
  assert_eq(
    is_marketplace_plugin_dir([
      { name: ".claude-plugin", is_dir: true, is_file: false },
    ]),
    true,
  )
  // a directory named plugin.json is not the marker.
  assert_eq(
    is_marketplace_plugin_dir([
      { name: "plugin.json", is_dir: true, is_file: false },
    ]),
    false,
  )
  // a file named .claude-plugin is not the marker.
  assert_eq(
    is_marketplace_plugin_dir([
      { name: ".claude-plugin", is_dir: false, is_file: true },
    ]),
    false,
  )
  // a symlink named plugin.json is invisible, so not the marker.
  assert_eq(
    is_marketplace_plugin_dir([
      { name: "plugin.json", is_dir: false, is_file: false },
    ]),
    false,
  )
}

///|
test "is_skill_dir" {
  assert_eq(
    is_skill_dir([{ name: "SKILL.md", is_dir: false, is_file: true }]),
    true,
  )
  // a directory named SKILL.md is not the marker.
  assert_eq(
    is_skill_dir([{ name: "SKILL.md", is_dir: true, is_file: false }]),
    false,
  )
  // a symlink named SKILL.md is invisible, so not the marker.
  assert_eq(
    is_skill_dir([{ name: "SKILL.md", is_dir: false, is_file: false }]),
    false,
  )
  assert_eq(
    is_skill_dir([{ name: "readme.md", is_dir: false, is_file: true }]),
    false,
  )
}
