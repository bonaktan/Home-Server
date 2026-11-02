# Host change register

Status: **inventory only; no changes approved for application by this register**. Original installation history remains unknown. See the [host investigation](../investigations/2026-11-01-debian-host-baseline.md) for source, date, confidence and limitations.

| Area | Observed / repository intent | Target and prerequisite | Apply, validation and rollback |
| --- | --- | --- | --- |
| Boot and Wi-Fi | Running `pcie_aspm=off`; Wi-Fi module options are present but effective values and rationale are unknown. | Preserve during adoption; establish hardware rationale and effective state. | No change selected. Record owning module, reboot, validation, previous boot and rollback before any change. |
| Network | Wi-Fi is active; old script assumes a static wired interface. | Inventory management and recovery routes, resolver ownership and intended stable addressing. | No change selected. Independently test SSH and arm bounded rollback before applying. |
| Firewall | Persistent service active; effective rules and backend are unverified. | Inspect privileged state and preserve Docker/Tailscale chains. | No change selected; do not flush rules. Record validation and phase rollback. |
| Package reporting | Native apt-listchanges hook and a conflicting custom hook exist; MOTD truncates shared history. | Adopt native integration and non-truncating reporting after disposable privacy/behavior tests. | Record exact files, prior state and package ownership; validate interactive/noninteractive upgrades and restore previous files on failure. Preserve live PAM. |
| Certificates | Public certificates and nginx configuration were observed; renewal ownership and reload are not established. | Inventory all schedules, credentials and consumers before adopting renewal. | Validate staging renewal and consumer reload, preserve previous configuration and recovery material. |

Every accepted change must add effective and target state, rationale, confidence, owner, restart/reboot needs, validation, rollback and drift check. This table does not claim package defaults or complete conffile coverage.
