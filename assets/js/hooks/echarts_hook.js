// LiveView hook that owns an ECharts instance for the lifetime of the
// element. The DOM target carries the chart options as a JSON string in
// `data-option`; updates re-render the chart only if the payload changed.
//
// Usage in HEEx:
//   <div id="my-chart" phx-hook="ECharts" data-option={Jason.encode!(opts)} />

import * as echarts from "../../vendor/echarts.min.js"

const ECharts = {
  mounted() {
    this.chart = echarts.init(this.el, null, { renderer: "canvas" })
    this.lastOption = null
    this.render()

    this.resizeHandler = () => this.chart && this.chart.resize()
    window.addEventListener("resize", this.resizeHandler)
  },

  updated() {
    this.render()
  },

  destroyed() {
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
    }
    if (this.chart) {
      this.chart.dispose()
      this.chart = null
    }
  },

  render() {
    const raw = this.el.dataset.option
    if (!raw || raw === this.lastOption) {
      return
    }

    try {
      const option = JSON.parse(raw)
      this.chart.setOption(option, true)
      this.lastOption = raw
    } catch (err) {
      console.error("[ECharts hook] invalid JSON in data-option", err)
    }
  },
}

export default ECharts
