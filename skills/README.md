# Personal skills

Put your own opencode skills here, one directory per skill, each with a
`SKILL.md` (see the opencode skill format):

```
skills/
  my-skill/
    SKILL.md
```

`bootstrap.sh` symlinks every `skills/<name>/` that has a `SKILL.md` into
`~/.config/opencode/skills/`, so anything you add here is installed on a fresh
machine automatically.

Note: firstmate's own skills (19 of them under `.agents/skills/`) ship inside
the `kunchenguid/firstmate` distro and are pulled automatically by the bootstrap
when it clones that repo — you don't need to copy them here.
