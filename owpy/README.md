# owpy

We have the following directories:

- [applications](applications): Code for running applications. These are the ones that can be started as a sub-process from the main script. Each of these have their own logging (to resolve issues with multiprocessing and logging) and configuration.
- [analysis](analysis): Code for analyzing data
- [capture](capture): Code for capturing data
- [cnc](cnc): cnc code
- [data](data): data/file management
- [neulog](neulog): neulog code
- [openwifi](openwifi): openwifi board management code
- [params](params): parameters for the experiments (for code in `cnc`, `neulog`, `openwifi` and `processing`)
- [processing](processing): Code for processing data, reconfiguring registers/openwifi etc. live
- [visualization](visualization): Code for plotting
- [wifi](wifi): Code related to Wi-Fi

## Logging

Logging should be done to one of the main loggers defined in the applications in [apps](apps)

- `cnc_app`
- `iq_capture_app`
- `processing_app`
