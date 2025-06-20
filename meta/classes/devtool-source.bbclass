#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

# Development tool - source extraction helper class
#
# NOTE: this class is intended for use by devtool and should not be
# inherited manually.
#
# Copyright (C) 2014-2017 Intel Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


DEVTOOL_TEMPDIR ?= ""

python() {
    tempdir = d.getVar('DEVTOOL_TEMPDIR')

    if not tempdir:
        bb.fatal('devtool-source class is for internal use by devtool only')

    # Make a subdir so we guard against WORKDIR==S
    workdir = os.path.join(tempdir, 'workdir')
    d.setVar('WORKDIR', workdir)
    if not d.getVar('S').startswith(workdir):
        # Usually a shared workdir recipe (kernel, gcc)
        # Try to set a reasonable default
        if bb.data.inherits_class('kernel', d):
            d.setVar('S', '${WORKDIR}/source')
        else:
            d.setVar('S', '${WORKDIR}/%s' % os.path.basename(d.getVar('S')))
    if bb.data.inherits_class('kernel', d):
        # We don't want to move the source to STAGING_KERNEL_DIR here
        d.setVar('STAGING_KERNEL_DIR', '${S}')

    d.setVar('STAMPS_DIR', os.path.join(tempdir, 'stamps'))
    d.setVar('T', os.path.join(tempdir, 'temp'))

    # Hook in pre/postfuncs
    is_kernel_yocto = bb.data.inherits_class('kernel-yocto', d)
    if is_kernel_yocto:
        unpacktask = 'do_kernel_checkout'
        d.appendVarFlag('do_configure', 'postfuncs', ' devtool_post_configure')
    else:
        unpacktask = 'do_unpack'
    d.appendVarFlag(unpacktask, 'postfuncs', ' devtool_post_unpack')
    d.appendVarFlag('do_patch', 'postfuncs', ' devtool_post_patch')

    # NOTE: in order for the patch stuff to be fully functional,
    # PATCHTOOL and PATCH_COMMIT_FUNCTIONS need to be set; we can't
    # do that here because we can't guarantee the order of the anonymous
    # functions, so it gets done in the bbappend we create.
}


python devtool_post_unpack() {
    import oe.recipeutils
    import shutil
    sys.path.insert(0, os.path.join(d.getVar('COREBASE'), 'scripts', 'lib'))
    import scriptutils
    from devtool import setup_git_repo

    tempdir = d.getVar('DEVTOOL_TEMPDIR')
    workdir = d.getVar('WORKDIR')
    unpackdir = d.getVar('UNPACKDIR')
    srcsubdir = d.getVar('S')

    # Add locally copied files to gitignore as we add back to the metadata directly
    local_files = oe.recipeutils.get_recipe_local_files(d)
    srcabspath = os.path.abspath(srcsubdir)
    local_files = [fname for fname in local_files if
                    os.path.exists(os.path.join(unpackdir, fname)) and
                    srcabspath == unpackdir]
    if local_files:
        with open(os.path.join(tempdir, '.gitignore'), 'a+') as f:
            f.write('# Ignore local files, by default. Remove following lines'
                    'if you want to commit the directory to Git\n')
            for fname in local_files:
                f.write('%s\n' % fname)

    if srcsubdir.startswith(unpackdir) and os.path.dirname(srcsubdir) != unpackdir:
        # Handle if S is set to a subdirectory of the source
        srcsubdir = os.path.normpath(os.path.join(unpackdir, os.path.relpath(srcsubdir, unpackdir).split(os.sep)[0]))

    scriptutils.git_convert_standalone_clone(srcsubdir)

    # Make sure that srcsubdir exists
    bb.utils.mkdirhier(srcsubdir)
    if not os.listdir(srcsubdir):
        bb.warn("No source unpacked to S - either the %s recipe "
                "doesn't use any source or the correct source "
                "directory could not be determined" % d.getVar('PN'))

    devbranch = d.getVar('DEVTOOL_DEVBRANCH')
    setup_git_repo(srcsubdir, d.getVar('PV'), devbranch, d=d)

    (stdout, _) = bb.process.run('git rev-parse HEAD', cwd=srcsubdir)
    initial_rev = stdout.rstrip()
    with open(os.path.join(tempdir, 'initial_rev'), 'w') as f:
        f.write(initial_rev)

    with open(os.path.join(tempdir, 'srcsubdir'), 'w') as f:
        f.write(srcsubdir)
}

python devtool_post_patch() {
    import shutil
    tempdir = d.getVar('DEVTOOL_TEMPDIR')
    with open(os.path.join(tempdir, 'srcsubdir'), 'r') as f:
        srcsubdir = f.read()
    with open(os.path.join(tempdir, 'initial_rev'), 'r') as f:
        initial_rev = f.read()

    def rm_patches():
        patches_dir = os.path.join(srcsubdir, 'patches')
        if os.path.exists(patches_dir):
            shutil.rmtree(patches_dir)
        # Restore any "patches" directory that was actually part of the source tree
        try:
            bb.process.run('git checkout -- patches', cwd=srcsubdir)
        except bb.process.ExecutionError:
            pass

    extra_overrides = d.getVar('DEVTOOL_EXTRA_OVERRIDES')
    if extra_overrides:
        extra_overrides = set(extra_overrides.split(':'))
        devbranch = d.getVar('DEVTOOL_DEVBRANCH')
        default_overrides = d.getVar('OVERRIDES').split(':')
        no_overrides = []
        # First, we may have some overrides that are referred to in the recipe set in
        # our configuration, so we need to make a branch that excludes those
        for override in default_overrides:
            if override not in extra_overrides:
                no_overrides.append(override)
        if default_overrides != no_overrides:
            # Some overrides are active in the current configuration, so
            # we need to create a branch where none of the overrides are active
            bb.process.run('git checkout %s -b devtool-no-overrides' % initial_rev, cwd=srcsubdir)
            # Run do_patch function with the override applied
            localdata = bb.data.createCopy(d)
            localdata.setVar('OVERRIDES', ':'.join(no_overrides))
            localdata.setVar('FILESOVERRIDES', ':'.join(no_overrides))
            bb.build.exec_func('do_patch', localdata)
            rm_patches()
            # Now we need to reconcile the dev branch with the no-overrides one
            # (otherwise we'd likely be left with identical commits that have different hashes)
            bb.process.run('git checkout %s' % devbranch, cwd=srcsubdir)
            bb.process.run('git rebase devtool-no-overrides', cwd=srcsubdir)
        else:
            bb.process.run('git checkout %s -b devtool-no-overrides' % devbranch, cwd=srcsubdir)

        for override in extra_overrides:
            localdata = bb.data.createCopy(d)
            if override in default_overrides:
                bb.process.run('git branch devtool-override-%s %s' % (override, devbranch), cwd=srcsubdir)
            else:
                # Reset back to the initial commit on a new branch
                bb.process.run('git checkout %s -b devtool-override-%s' % (initial_rev, override), cwd=srcsubdir)
                # Run do_patch function with the override applied
                localdata.setVar('OVERRIDES', ':'.join(no_overrides + [override]))
                localdata.setVar('FILESOVERRIDES', ':'.join(no_overrides + [override]))
                bb.build.exec_func('do_patch', localdata)
                rm_patches()
                # Now we need to reconcile the new branch with the no-overrides one
                # (otherwise we'd likely be left with identical commits that have different hashes)
                bb.process.run('git rebase devtool-no-overrides', cwd=srcsubdir)
        bb.process.run('git checkout %s' % devbranch, cwd=srcsubdir)
    bb.process.run('git tag -f --no-sign devtool-patched', cwd=srcsubdir)
    if os.path.exists(os.path.join(srcsubdir, '.gitmodules')):
        bb.process.run('git submodule foreach --recursive  "git tag -f --no-sign devtool-patched"', cwd=srcsubdir)

}

python devtool_post_configure() {
    import shutil
    tempdir = d.getVar('DEVTOOL_TEMPDIR')
    shutil.copy2(os.path.join(d.getVar('B'), '.config'), tempdir)
}
